"""Download ONLY the pinned official buffalo_s pack into a private cache. No biometric dataset."""
import argparse,hashlib,json,os,urllib.request,zipfile
from pathlib import Path
SOURCE='https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_s.zip'
SIZE=127607557
ZIP_SHA256='d85a87f503f691807cd8bb97128bdf7a0660326cd9cd02657127fa978bab8b5e'
ARTIFACTS={'det_500m.onnx':'5e4447f50245bbd7966bd6c0fa52938c61474a04ec7def48753668a9d8b4ea3a','w600k_mbf.onnx':'9cc6e4a75f0e2bf0b1aed94578f144d15175f357bdc05e815e5c4a02b319eb4f'}
def main():
    a=argparse.ArgumentParser();a.add_argument('--private-directory',type=Path,required=True);v=a.parse_args();p=v.private_directory.resolve()
    if (Path(os.environ['LOCALAPPDATA'])/'Temp').resolve() not in p.parents:raise ValueError('Dedicated private Temp cache required')
    p.mkdir(parents=True,exist_ok=True);bundle=p/'buffalo_s.zip'
    if not bundle.exists():
        temporary=p/'buffalo_s.download'
        if temporary.exists():raise ValueError('Unfinished download exists; inspect instead of overwriting')
        urllib.request.urlretrieve(SOURCE,temporary)
        if temporary.stat().st_size!=SIZE or hashlib.sha256(temporary.read_bytes()).hexdigest()!=ZIP_SHA256:raise ValueError('Official asset differs from recorded rehearsal hash; review upstream')
        temporary.rename(bundle)
    if bundle.stat().st_size!=SIZE or hashlib.sha256(bundle.read_bytes()).hexdigest()!=ZIP_SHA256:raise ValueError('Cached asset checksum mismatch')
    root=p/'model-root'/'models'/'buffalo_s';root.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(bundle) as z:
        for name,digest in ARTIFACTS.items():
            raw=z.read(name)
            if hashlib.sha256(raw).hexdigest()!=digest:raise ValueError('Artifact checksum mismatch')
            target=root/name
            if target.exists():
                if hashlib.sha256(target.read_bytes()).hexdigest()!=digest:raise ValueError('Existing model differs; refuse overwrite')
            else:
                with target.open('xb') as out:out.write(raw)
    print(json.dumps({'source':SOURCE,'localRecordedSha256':ZIP_SHA256,'publisherChecksumAvailable':False,'modelRoot':str(root.parent.parent),'artifacts':ARTIFACTS},indent=2))
if __name__=='__main__':main()
