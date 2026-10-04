"""macOS integration harness: real Git, fake GitHub HTTP and isolated bare remote.
Development only: requires Python 3. Never uses a real PAT or live GitHub.
"""
import unittest, tempfile, pathlib, subprocess, os, json, shutil
ROOT=pathlib.Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'github-pages-beginner/scripts/publish.sh'
GIT=shutil.which('git')
FAKE='workshop_test_credential_0123456789'
CURL=r'''#!/usr/bin/env python3
import os,sys,json,pathlib,subprocess
args=sys.argv[1:];url=args[-1];state=pathlib.Path(os.environ['MOCK_STATE'])
d=json.loads(state.read_text());method=args[args.index('-X')+1] if '-X' in args else 'GET'
endpoint=url.split('api.github.com')[-1]
code=200; body={}
if d.get('network'):sys.exit(6)
if 'github.io' in url:
 assert '-H' not in args, 'Authorization sent to public website'
 body=subprocess.check_output([os.environ['REAL_GIT'],'show','HEAD:index.html'],text=True) if not d.get('stale') else 'old content'
elif endpoint=='/user':code=d.get('user_status',200);body={'login':'student','id':123}
elif endpoint=='/user/repos':
 code=d.get('create_status',201);d['repo']=True;body={'name':'site'}
elif endpoint.endswith('/pages/builds/latest'):
 sha=subprocess.check_output([os.environ['REAL_GIT'],'rev-parse','HEAD'],text=True).strip()
 body={'commit':sha,'status':'errored' if d.get('build_failure') else 'built'}
elif endpoint.endswith('/pages'):
 if method=='GET':code=200 if d.get('pages') else 404;body={'source':{'branch':'main','path':d.get('source','/')},'cname':None,'build_type':'legacy'}
 elif method=='POST':code=201;d['pages']=True
 else:code=204;d['source']='/'
else:code=200 if d.get('repo') or (d.get('collision') and not endpoint.endswith('-2')) else 404;body={'private':False}
if code==403 and d.get('rate'):body={'message':'API rate limit exceeded'}
if '-D' in args:pathlib.Path(args[args.index('-D')+1]).write_text('')
pathlib.Path(args[args.index('-o')+1]).write_text(body if isinstance(body,str) else json.dumps(body))
d.setdefault('calls',[]).append([method,endpoint]);state.write_text(json.dumps(d));print(code,end='')
'''
WRAPPER=r'''#!/usr/bin/env python3
import os,sys,subprocess,json,pathlib
args=sys.argv[1:]
state=pathlib.Path(os.environ['MOCK_STATE']);d=json.loads(state.read_text())
if 'push' in args and d.get('fail_push'):
 d['fail_push']=False;state.write_text(json.dumps(d));sys.exit(1)
for command in ['push','fetch','ls-remote']:
 if command in args:
  i=args.index(command)
  if 'origin' in args[i+1:]:args[args.index('origin',i+1)]=os.environ['MOCK_REMOTE']
  args=[a for a in args if a!='-u']
  break
raise SystemExit(subprocess.call([os.environ['REAL_GIT']]+args))
'''
class Publish(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory(prefix='pages-tests-');self.base=pathlib.Path(self.tmp.name)
  self.workspace=self.base/'web-create-deploy';self.workspace.mkdir()
  self.site=self.workspace/'中文 My Website';self.site.mkdir();(self.site/'index.html').write_text('<h1>Version 1</h1>\n')
  (self.workspace/'github_pat.txt').write_text(FAKE)
  self.bin=self.base/'bin';self.bin.mkdir()
  for name,content in [('curl',CURL),('git',WRAPPER)]:
   p=self.bin/name;p.write_text(content);p.chmod(0o700)
  self.remote=self.base/'remote.git';subprocess.run([GIT,'init','--bare','-q',str(self.remote)],check=True)
  self.state=self.base/'state.json';self.state.write_text('{}')
  self.scratch=self.base/'scratch';self.scratch.mkdir()
  self.env=dict(os.environ,TMPDIR=str(self.scratch),PATH=str(self.bin)+os.pathsep+os.environ['PATH'],MOCK_STATE=str(self.state),MOCK_REMOTE=str(self.remote),REAL_GIT=GIT)
 def tearDown(self):self.tmp.cleanup()
 def config(self,**kw):
  d=json.loads(self.state.read_text());d.update(kw);self.state.write_text(json.dumps(d))
 def run_script(self,*args):
  r=subprocess.run(['bash',str(SCRIPT),'--project-dir',str(self.site),'--wait-seconds','0',*args],env=self.env,text=True,capture_output=True)
  self.assertNotIn(FAKE,r.stdout+r.stderr)
  self.assertEqual(list(self.scratch.iterdir()),[], 'Temporary credentials not cleaned')
  try:return json.loads(r.stdout)
  except Exception:self.fail(repr((r.returncode,r.stdout,r.stderr)))
 def git(self,*args):return subprocess.check_output([GIT,'-C',str(self.site),*args],text=True).strip()
 def test_publish_update_unchanged(self):
  first=self.run_script();self.assertTrue(first['ok']);self.assertNotIn('github_pat.txt',self.git('ls-files'))
  (self.site/'index.html').write_text('<h1>Version 2</h1>\n')
  second=self.run_script();self.assertTrue(second['ok']);self.assertEqual(first['pages_url'],second['pages_url']);self.assertNotEqual(first['commit'],second['commit'])
  third=self.run_script();self.assertEqual(third['action'],'unchanged');self.assertEqual(second['commit'],third['commit'])
  self.assertNotIn(FAKE,self.git('config','--local','--list'))
  self.assertNotIn(FAKE,subprocess.check_output([GIT,'--git-dir',str(self.remote),'show','main:index.html'],text=True))
 def test_missing(self):
  (self.workspace/'github_pat.txt').unlink();self.assertEqual(self.run_script()['code'],'TOKEN_MISSING');self.assertFalse((self.site/'.git').exists())
 def test_empty(self):
  (self.workspace/'github_pat.txt').write_text('');self.assertEqual(self.run_script()['code'],'TOKEN_EMPTY')
 def test_invalid(self):
  self.config(user_status=401);self.assertEqual(self.run_script()['code'],'TOKEN_INVALID')
 def test_permission(self):
  self.config(user_status=403);self.assertEqual(self.run_script()['code'],'TOKEN_PERMISSION')
 def test_rate(self):
  self.config(user_status=403,rate=True);self.assertEqual(self.run_script()['code'],'RATE_LIMITED')
 def test_network(self):
  self.config(network=True);self.assertEqual(self.run_script()['code'],'NETWORK_ERROR')
 def test_collision(self):
  self.config(collision=True);self.assertTrue(self.run_script()['repository'].endswith('-2'))
 def test_unicode(self):
  (self.site/'圖片').mkdir();(self.site/'圖片/台北.txt').write_text('台北');self.assertTrue(self.run_script()['ok'])
 def test_ignore(self):
  (self.site/'.gitignore').write_text('original/');self.assertTrue(self.run_script()['ok']);self.assertTrue((self.site/'.gitignore').read_text().startswith('original/\n'))
 def test_dry(self):
  self.assertEqual(self.run_script('--dry-run')['action'],'dry-run');self.assertFalse((self.site/'.git').exists());self.assertEqual(self.state.read_text(),'{}')
 def test_missing_entry(self):
  (self.site/'index.html').rename(self.site/'website.html');self.assertEqual(self.run_script()['code'],'SITE_ENTRY_MISSING')
 def test_large(self):
  with (self.site/'large.bin').open('wb') as f:f.truncate(104857600)
  self.assertEqual(self.run_script()['code'],'FILE_TOO_LARGE')
 def test_secret_copy(self):
  (self.site/'oops.txt').write_text(FAKE);self.assertEqual(self.run_script()['code'],'SECRET_IN_FILES')
 def test_history(self):
  (self.site/'github_pat-old.txt').write_text(FAKE)
  self.git('init','-q');self.git('symbolic-ref','HEAD','refs/heads/main');self.git('config','user.name','Test');self.git('config','user.email','test@example.invalid');self.git('add','.');self.git('commit','-qm','test')
  self.assertEqual(self.run_script()['code'],'SECRET_IN_HISTORY')
 def test_unrelated_remote(self):
  self.git('init','-q');self.git('symbolic-ref','HEAD','refs/heads/main');self.git('remote','add','origin','https://github.com/other/site.git')
  self.assertEqual(self.run_script()['code'],'UNMANAGED_REMOTE');self.assertEqual(self.git('remote','get-url','origin'),'https://github.com/other/site.git')
 def test_wrong_source(self):
  self.assertTrue(self.run_script()['ok']);self.config(source='/docs');self.assertTrue(self.run_script()['ok']);self.assertEqual(json.loads(self.state.read_text())['source'],'/')
 def test_build_fail(self):
  self.config(build_failure=True);self.assertEqual(self.run_script()['code'],'PAGES_BUILD_FAILED')
 def test_stale(self):
  self.config(stale=True);self.assertEqual(self.run_script()['code'],'PAGES_BUILD_PENDING')
 def test_create_422(self):
  self.config(create_status=422);self.assertEqual(self.run_script()['code'],'REPO_CREATE_FAILED')
 def test_create_409(self):
  self.config(create_status=409);self.assertEqual(self.run_script()['code'],'REPO_CREATE_FAILED')
 def test_symlink(self):
  (self.site/'link').symlink_to(self.site/'index.html');self.assertEqual(self.run_script()['code'],'SYMLINK_UNSUPPORTED')
 def test_bom(self):
  (self.workspace/'github_pat.txt').write_text('\ufeff'+FAKE+'\r\n');self.assertTrue(self.run_script()['ok'])
 def test_first_push_retry(self):
  self.config(fail_push=True);self.assertEqual(self.run_script()['code'],'GIT_PUSH_FAILED')
  self.assertTrue(self.run_script()['ok'])
 def test_crlf(self):
  self.git('init','-q');self.git('symbolic-ref','HEAD','refs/heads/main');self.git('config','core.autocrlf','true')
  (self.site/'index.html').write_bytes(b'<h1>Version 1</h1>\r\n')
  self.assertTrue(self.run_script()['ok'])
 def test_chinese_name(self):
  new=self.workspace/'我的網頁作品';self.site.rename(new);self.site=new
  self.assertEqual(self.run_script()['repository'],'my-webpage')
 def test_missing_git(self):
  (self.bin/'git').write_text('#!/bin/sh\nexit 127\n')
  self.assertEqual(self.run_script()['code'],'GIT_MISSING')
 def test_diverged(self):
  self.assertTrue(self.run_script()['ok'])
  clone=self.base/'other';subprocess.run([GIT,'clone','-q','-b','main',str(self.remote),str(clone)],check=True)
  subprocess.run([GIT,'-C',str(clone),'config','user.name','Test'],check=True);subprocess.run([GIT,'-C',str(clone),'config','user.email','test@example.invalid'],check=True)
  (clone/'other.txt').write_text('another version');subprocess.run([GIT,'-C',str(clone),'add','.'],check=True);subprocess.run([GIT,'-C',str(clone),'commit','-qm','other'],check=True);subprocess.run([GIT,'-C',str(clone),'push','-q','origin','main'],check=True)
  self.assertEqual(self.run_script()['code'],'REMOTE_DIVERGED')
 def test_root_rejected(self):
  self.site=self.workspace
  (self.site/'index.html').write_text('root must not publish')
  self.assertEqual(self.run_script()['code'],'WORKSPACE_LAYOUT')
  self.assertEqual(self.state.read_text(),'{}')
 def test_token_inside_rejected(self):
  (self.site/'github_pat.txt').write_text(FAKE)
  self.assertEqual(self.run_script()['code'],'TOKEN_INSIDE_SITE')
 def test_sibling_not_published(self):
  sibling=self.workspace/'web-app-other';sibling.mkdir();(sibling/'private.txt').write_text('not this website')
  (self.workspace/'AGENTS.md').write_text('workspace instructions')
  self.assertTrue(self.run_script()['ok'])
  files=self.git('ls-tree','-r','--name-only','HEAD').splitlines()
  self.assertNotIn('AGENTS.md',files);self.assertNotIn('private.txt',files)
  self.assertFalse((self.workspace/'.git').exists());self.assertFalse((sibling/'.git').exists())
 def test_parent_token_symlink(self):
  token=self.workspace/'github_pat.txt';token.rename(self.base/'real.txt');token.symlink_to(self.base/'real.txt')
  self.assertEqual(self.run_script()['code'],'TOKEN_FILE_UNSAFE')
 def test_unicode_secret_history(self):
  for filename in ['.env','secret.pem','secret.key']:
   folder=self.site/'中文';folder.mkdir(exist_ok=True);(folder/filename).write_text('SECRET=not_current_pat')
  self.git('init','-q');self.git('symbolic-ref','HEAD','refs/heads/main');self.git('config','user.name','Test');self.git('config','user.email','test@example.invalid');self.git('add','.');self.git('commit','-qm','test')
  self.assertEqual(self.run_script()['code'],'SECRET_IN_HISTORY');self.assertEqual(self.state.read_text(),'{}')
 def test_newline_secret_history(self):
  folder=self.site/'line\nbreak';folder.mkdir();(folder/'.env').write_text('SECRET=not_current_pat')
  self.git('init','-q');self.git('symbolic-ref','HEAD','refs/heads/main');self.git('config','user.name','Test');self.git('config','user.email','test@example.invalid');self.git('add','.');self.git('commit','-qm','test')
  self.assertEqual(self.run_script()['code'],'SECRET_IN_HISTORY')
if __name__=='__main__':unittest.main(verbosity=2)
