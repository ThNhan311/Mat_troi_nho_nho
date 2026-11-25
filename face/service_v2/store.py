"""Durable staged gallery. SQLite transaction covers metadata + encrypted vector payload only.
No claim of a distributed transaction with Backend PostgreSQL. No raw images retained.
"""
import base64
import hashlib
import json
import sqlite3
from contextlib import contextmanager
from pathlib import Path
import numpy as np
from cryptography.fernet import Fernet
from face.prototype.gallery import Gallery, _normalize
from face.prototype.enroll import register, DuplicateIdentityError

class Fault(Exception):
    def __init__(self, code, status=409):
        super().__init__(code)
        self.code, self.status = code, status

class Store:
    def __init__(self, path, key, model, duplicate_threshold):
        self.path, self.cipher, self.model = str(path), Fernet(key.encode()), model
        self.duplicate_threshold = duplicate_threshold
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with self.transaction() as db:
            db.execute("CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY,value TEXT NOT NULL)")
            old = db.execute("SELECT value FROM metadata WHERE key='model'").fetchone()
            if old and old[0] != model: raise Fault('MODEL_MISMATCH')
            db.execute("INSERT OR IGNORE INTO metadata VALUES('model',?)", (model,))
            db.execute("""CREATE TABLE IF NOT EXISTS operations (
                operation TEXT PRIMARY KEY, member TEXT NOT NULL, profile TEXT UNIQUE NOT NULL,
                reference TEXT UNIQUE NOT NULL, predecessor TEXT, generation INTEGER NOT NULL CHECK(generation>0),
                fingerprint TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('PREPARED','STAGED','ACTIVE','REPLACED','ABORTED')),
                vectors BLOB, sample_digest TEXT, UNIQUE(member,generation))""")
            db.execute("CREATE UNIQUE INDEX IF NOT EXISTS one_active ON operations(member) WHERE status='ACTIVE'")
            db.execute("CREATE TABLE IF NOT EXISTS tombstones(reference TEXT PRIMARY KEY)")
            db.execute("CREATE TABLE IF NOT EXISTS captures(capture TEXT PRIMARY KEY,request TEXT NOT NULL,digest TEXT NOT NULL,attestation TEXT NOT NULL)")
            key_id=hashlib.sha256(key.encode()).hexdigest()
            previous=db.execute("SELECT value FROM metadata WHERE key='key-id'").fetchone()
            if previous and previous[0]!=key_id:raise Fault('GALLERY_KEY_MISMATCH')
            if not previous:
                existing=db.execute('SELECT vectors FROM operations WHERE vectors IS NOT NULL LIMIT 1').fetchone()
                if existing:
                    try:self.cipher.decrypt(existing[0])
                    except Exception:raise Fault('GALLERY_KEY_MISMATCH') from None
                db.execute("INSERT INTO metadata VALUES('key-id',?)",(key_id,))

    @contextmanager
    def transaction(self):
        db = sqlite3.connect(self.path, timeout=5, isolation_level=None)
        db.row_factory = sqlite3.Row
        try:
            db.execute('PRAGMA foreign_keys=ON'); db.execute('PRAGMA synchronous=FULL'); db.execute('BEGIN IMMEDIATE')
            yield db
            db.commit()
        except BaseException:
            db.rollback(); raise
        finally: db.close()

    @staticmethod
    def public(row):
        return {k: row[k] for k in ['operation','member','profile','reference','predecessor','generation','status']}

    def _get(self, db, operation):
        row = db.execute('SELECT * FROM operations WHERE operation=?', (operation,)).fetchone()
        if not row: raise Fault('NOT_FOUND',404)
        return row

    def _live(self, db, row):
        if row['status'] in ('ABORTED','REPLACED') or db.execute('SELECT 1 FROM tombstones WHERE reference=?',(row['reference'],)).fetchone():
            raise Fault('TOMBSTONED')

    def prepare(self, operation, member, profile, reference, predecessor):
        fingerprint = hashlib.sha256(json.dumps([operation,member,profile,reference,predecessor],separators=(',',':')).encode()).hexdigest()
        with self.transaction() as db:
            row = db.execute('SELECT * FROM operations WHERE operation=?',(operation,)).fetchone()
            if row:
                if row['fingerprint'] != fingerprint: raise Fault('BINDING_CONFLICT')
                return self.public(row)
            if db.execute('SELECT 1 FROM tombstones WHERE reference=?',(reference,)).fetchone(): raise Fault('TOMBSTONED')
            active = db.execute("SELECT reference FROM operations WHERE member=? AND status='ACTIVE'",(member,)).fetchone()
            if (active['reference'] if active else None) != predecessor: raise Fault('PREDECESSOR_CONFLICT')
            # A predecessor must be a managed reference belonging to this Member, never an arbitrary alias.
            if predecessor and not db.execute('SELECT 1 FROM operations WHERE member=? AND reference=?',(member,predecessor)).fetchone(): raise Fault('PREDECESSOR_CONFLICT')
            generation = db.execute('SELECT coalesce(max(generation),0)+1 FROM operations WHERE member=?',(member,)).fetchone()[0]
            try: db.execute("INSERT INTO operations(operation,member,profile,reference,predecessor,generation,fingerprint,status) VALUES(?,?,?,?,?,?,?,'PREPARED')",(operation,member,profile,reference,predecessor,generation,fingerprint))
            except sqlite3.IntegrityError: raise Fault('BINDING_CONFLICT') from None
            return self.public(self._get(db,operation))

    def _gallery(self, db):
        gallery = Gallery(self.model)
        for row in db.execute("SELECT * FROM operations WHERE status='ACTIVE'"):
            vectors = json.loads(self.cipher.decrypt(row['vectors']))
            gallery.add(row['member'], vectors)
        return gallery

    def _duplicate_check(self, db, member, vectors):
        # Reserve against ACTIVE and STAGED candidates. Publication cannot introduce an
        # intervening duplicate after the Backend commits its replacement mapping.
        gallery=Gallery(self.model)
        for other in db.execute("SELECT member,vectors FROM operations WHERE status IN ('ACTIVE','STAGED') AND member<>?",(member,)):
            values=json.loads(self.cipher.decrypt(other['vectors']))
            gallery.add(other['member'],(gallery.get(other['member']) or [])+values)
            reverse=Gallery(self.model);reverse.add(member,vectors)
            if reverse.search(np.mean(values,axis=0))[0][1]>=self.duplicate_threshold:
                raise Fault('DUPLICATE_IDENTITY')
        try:register(gallery,member,vectors,self.duplicate_threshold)
        except DuplicateIdentityError:raise Fault('DUPLICATE_IDENTITY') from None

    def stage(self, operation, vectors, digest):
        vectors = [_normalize(v).tolist() for v in vectors]
        if len(vectors)<3: raise Fault('INSUFFICIENT_SAMPLES',400)
        with self.transaction() as db:
            row=self._get(db,operation); self._live(db,row)
            if row['sample_digest']:
                if row['sample_digest']!=digest: raise Fault('SAMPLE_CONFLICT')
                return self.public(row)
            self._duplicate_check(db,row['member'],vectors)
            db.execute("UPDATE operations SET vectors=?,sample_digest=?,status='STAGED' WHERE operation=?",(self.cipher.encrypt(json.dumps(vectors).encode()),digest,operation))
            return self.public(self._get(db,operation))

    def finalize(self, operation, binding):
        with self.transaction() as db:
            row=self._get(db,operation); self._live(db,row)
            if any(row[k]!=binding[k] for k in ['member','profile','reference','generation']): raise Fault('BINDING_CONFLICT')
            if row['status']=='ACTIVE': return self.public(row)
            if row['status']!='STAGED': raise Fault('SAMPLE_NOT_READY')
            active=db.execute("SELECT * FROM operations WHERE member=? AND status='ACTIVE'",(row['member'],)).fetchone()
            if (active['reference'] if active else None)!=row['predecessor']: raise Fault('PREDECESSOR_CONFLICT')
            # Recheck duplicate under the write lock: another member may have finalized since staging.
            gallery=self._gallery(db)
            try: register(gallery,row['member'],json.loads(self.cipher.decrypt(row['vectors'])),self.duplicate_threshold)
            except DuplicateIdentityError: raise Fault('DUPLICATE_IDENTITY') from None
            db.execute("UPDATE operations SET status='REPLACED',vectors=NULL WHERE member=? AND status='ACTIVE'",(row['member'],))
            db.execute("UPDATE operations SET status='ACTIVE' WHERE operation=?",(operation,))
            return self.public(self._get(db,operation))

    def abort(self, reference):
        with self.transaction() as db:
            db.execute('INSERT OR IGNORE INTO tombstones VALUES(?)',(reference,))
            db.execute("UPDATE operations SET status='ABORTED',vectors=NULL WHERE reference=?",(reference,))
        return {'reference':reference,'status':'ABORTED'}

    def status(self, operation):
        with self.transaction() as db: return self.public(self._get(db,operation))

    def recognize(self, vector, request, capture, digest, decide):
        with self.transaction() as db:
            old=db.execute('SELECT * FROM captures WHERE capture=?',(capture,)).fetchone()
            if old:
                if old['request']!=request or old['digest']!=digest: raise Fault('CAPTURE_REUSED')
                return json.loads(old['attestation'])
            gallery=self._gallery(db)
            outcome, member, score, gap=decide(gallery,vector)
            row=db.execute("SELECT * FROM operations WHERE member=? AND status='ACTIVE'",(member,)).fetchone() if member else None
            result={'outcome':outcome,'score':score,'margin':gap,**({k:row[k] for k in ['profile','reference','generation']} if row else {'profile':None,'reference':None,'generation':None})}
            return result

    def save_capture(self, request, capture, digest, attestation):
        with self.transaction() as db:
            try: db.execute('INSERT INTO captures VALUES(?,?,?,?)',(capture,request,digest,json.dumps(attestation,separators=(',',':'))))
            except sqlite3.IntegrityError:
                old=db.execute('SELECT * FROM captures WHERE capture=?',(capture,)).fetchone()
                if old['request']!=request or old['digest']!=digest: raise Fault('CAPTURE_REUSED') from None
                return json.loads(old['attestation'])
        return attestation

    def capture(self, request, capture):
        with self.transaction() as db:
            row=db.execute('SELECT * FROM captures WHERE capture=? AND request=?',(capture,request)).fetchone()
            if not row: raise Fault('NOT_FOUND',404)
            return json.loads(row['attestation'])
