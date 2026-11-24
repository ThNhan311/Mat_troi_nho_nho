import argparse,json,os
from pathlib import Path
from .runtime import Runtime,probe

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--config',type=Path);parser.add_argument('--probe',type=Path);args=parser.parse_args()
    if args.probe:print(json.dumps(probe(args.probe),indent=2));return
    if not args.config:parser.error('--config or --probe required')
    path=args.config.resolve(strict=True);temp=(Path(os.environ['LOCALAPPDATA'])/'Temp').resolve()
    if temp not in path.parents:raise SystemExit('Private Temp configuration required')
    d=json.loads(path.read_text(encoding='utf-8'))
    if d.get('guard')!='F03A_PRIVATE_REHEARSAL' or not 1024<=d['port']<=65535:raise SystemExit('Explicit rehearsal guard required')
    from .store import Store
    from .api import create_app
    import uvicorn
    engine=Runtime(d['modelRoot'])
    store=Store(path.parent/'staged-gallery.sqlite',d['galleryKey'],engine.model_name,d['duplicateThreshold'])
    app=create_app(store,engine,d['controlToken'],d['captureToken'],d['signingKey'],d['threshold'],d['margin'])
    uvicorn.run(app,host='127.0.0.1',port=d['port'],access_log=False)
if __name__=='__main__':main()
