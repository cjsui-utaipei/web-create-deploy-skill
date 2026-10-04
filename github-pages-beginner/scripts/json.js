// macOS JXA fallback; no UI automation. Read JSON from a file, never from command arguments.
function run(argv) {
 ObjC.import('Foundation');
 const s=$.NSString.stringWithContentsOfFileEncodingError(argv[0],$.NSUTF8StringEncoding,null);
 let value=JSON.parse(ObjC.unwrap(s));
 for (const key of argv[1].split('.')) value=value==null?undefined:value[key];
 return value==null?'':String(value);
}
