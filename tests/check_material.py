"""Offline material validation. Development only, Python standard library."""
from pathlib import Path
from html.parser import HTMLParser
import base64, io, zipfile, re, json, sys, subprocess
ROOT=Path(__file__).resolve().parents[1]
class Document(HTMLParser):
 def __init__(self):
  super().__init__();self.ids=[];self.images=[];self.links=[]
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if 'id' in a:self.ids.append(a['id'])
  if tag=='img' and a.get('src'):self.images.append(a['src'])
  if tag=='a':self.links.append(a)
s=(ROOT/'docs/新手完整圖解教學.html').read_text('utf-8');d=Document();d.feed(s)
assert len(d.ids)==len(set(d.ids))
assert len(d.images)==22
if '--baseline' in sys.argv:
 baseline=sys.argv[sys.argv.index('--baseline')+1]
 old=Document();old.feed(subprocess.check_output(['git','-C',str(ROOT),'show',baseline+':docs/新手完整圖解教學.html']).decode('utf-8'))
 assert len(old.images)==14 and all(image in d.images for image in old.images),'Original images changed'
for src in d.images:
 assert src.startswith('data:image/')
 data=base64.b64decode(src.split(',',1)[1],validate=True)
 assert data.startswith((b'\x89PNG\r\n\x1a\n',b'\xff\xd8\xff'))
for a in d.links:
 if a.get('href','').startswith('#'):assert a['href'][1:] in d.ids
 if a.get('class')=='original':assert a['href'] in d.images
downloads=[a for a in d.links if 'download' in a];assert len(downloads)==2
for a in downloads:
 blob=base64.b64decode(a['href'].split(',',1)[1],validate=True)
 if '--downloads' in sys.argv:
  download_dir=Path(sys.argv[sys.argv.index('--downloads')+1])
  assert (download_dir/a['download']).read_bytes()==blob,'Browser download differs from embedded ZIP'
 with zipfile.ZipFile(io.BytesIO(blob)) as z:
  assert z.testzip() is None
  for n in z.namelist():
   p=Path(n);assert p.name!='github_pat.txt';assert '..' not in p.parts
   source=ROOT/n if n.startswith('github-pages-beginner/') else ROOT/'starter'/n
   assert z.read(n).replace(b'\r\n',b'\n')==source.read_bytes().replace(b'\r\n',b'\n'),n
   assert not re.search(rb'(?:ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})',z.read(n)),n
print(json.dumps({'images':len(d.images),'embedded_zips':len(downloads),'anchors':'PASS','zip_source_match':'PASS','secret_pattern_scan':'PASS'}))
