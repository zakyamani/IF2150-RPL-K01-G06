import os,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[2]
class SigningTests(unittest.TestCase):
 def test_missing_signing_fails_before_build_with_clear_recovery(self):
  with tempfile.TemporaryDirectory(prefix='sisarasa-signing-test-') as d:
   p=subprocess.run(['bash',str(ROOT/'scripts/build-apk.sh'),'https://api.example.test'],env=dict(os.environ,SISARASA_SIGNING_FILE=str(pathlib.Path(d)/'key.properties')),capture_output=True,text=True)
   self.assertNotEqual(p.returncode,0)
   self.assertIn('key.properties',p.stderr)
   self.assertIn('setup-signing',p.stderr)
if __name__=='__main__': unittest.main()
