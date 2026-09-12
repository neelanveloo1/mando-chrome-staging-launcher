ObjC.import('Foundation');
function run(argv) {
  const input=$.NSFileHandle.fileHandleWithStandardInput,output=$.NSFileHandle.fileHandleWithStandardOutput;
  function reply(value){
    const body=$(JSON.stringify(value)).dataUsingEncoding($.NSUTF8StringEncoding);
    const n=Number(body.length);
    const bytes=[n&255,(n>>>8)&255,(n>>>16)&255,(n>>>24)&255];
    // Base64 avoids pointer bridging and preserves zero bytes in the prefix.
    const alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let b64='';for(let i=0;i<4;i+=3){const a=bytes[i],b=bytes[i+1],c=bytes[i+2];b64+=alphabet[a>>2]+alphabet[((a&3)<<4)|((b||0)>>4)]+(b===undefined?'=':alphabet[((b&15)<<2)|((c||0)>>6)])+(c===undefined?'=':alphabet[c&63]);}
    output.writeData($.NSData.alloc.initWithBase64EncodedStringOptions(b64,0));output.writeData(body);
  }
  try {
    if(argv[1]!=='chrome-extension://gonaohmomchmmkmnnioldofcabibpicp/')throw Error('Origin');
    const header=input.readDataOfLength(4);
    if(Number(header.length)!==4)throw Error('Header');
    const base64=ObjC.unwrap(header.base64EncodedStringWithOptions(0));
    const alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let bits=0,value=0,bytes=[];for(const c of base64){if(c==='=')break;value=(value<<6)|alphabet.indexOf(c);bits+=6;if(bits>=8){bits-=8;bytes.push((value>>bits)&255);}}
    const length=(bytes[0]|bytes[1]<<8|bytes[2]<<16|bytes[3]<<24)>>>0;
    if(length<1||length>1024)throw Error('Length');
    const body=input.readDataOfLength(length);if(Number(body.length)!==length)throw Error('Truncated');
    const request=JSON.parse(ObjC.unwrap($.NSString.alloc.initWithDataEncoding(body,$.NSUTF8StringEncoding)));
    if(request.action!=='status'||Object.keys(request).length!==1)throw Error('Request');
    const task=$.NSTask.alloc.init,pipe=$.NSPipe.pipe;
    task.launchPath='/bin/bash';task.arguments=[argv[0]+'/live-status.sh'];task.standardOutput=pipe;
    task.standardError=$.NSFileHandle.fileHandleWithStandardError;
    task.launch;
    const data=pipe.fileHandleForReading.readDataToEndOfFile;
    task.waitUntilExit;
    if(Number(task.terminationStatus)!==0)throw Error('Check failed');
    reply(JSON.parse(ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data,$.NSUTF8StringEncoding))));
  } catch { reply({check:'checker_error',latestSha:null,checkedAt:new Date().toISOString()}); }
}
