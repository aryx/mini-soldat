// Claude Code
//
// Copyright (C) 2026 Yoann Padioleau
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public License
// (LGPL) as published by the Free Software Foundation; either version
// 2 of the License, or (at your option) any later version.
//
// The game's page timed in a real Chrome, headless, over its DevTools
// protocol: each second, the frames drawn so far, the pictures the
// page had encoded as PNG (elm-playground's web platform does that for
// each picture it has not kept: canvas.toDataURL) and the time that
// took, the frames longer than 30 ms, and how many <image> the page
// holds. Space is pressed at the 4th second (a round starts) and d
// held from the 6th.
//
//   make serve-website &
//   node scripts/perf/web_probe.js "http://127.0.0.1:8000/play.html?graphics=3" 16
//
// A third argument is a file: the page's picture at the end, as PNG.
//
// How the limit of 32 pictures was found (docs/plan.md, "To decide"):
// 64 images in the page, 40 PNG encoded a frame, 9 frames a second.
// No dependency: the few lines of WebSocket a client needs are below.
const { spawn } = require("child_process"); const http = require("http"); const net=require("net"); const crypto=require("crypto");
const url = process.argv[2];
const chrome = spawn("google-chrome", ["--headless=new","--disable-gpu","--no-sandbox","--remote-debugging-port=9333","--window-size=1000,1000","about:blank"], {stdio:"ignore"});
function get(u){return new Promise((res,rej)=>http.get(u,r=>{let d="";r.on("data",c=>d+=c);r.on("end",()=>res(d));}).on("error",rej));}
(async()=>{
  let targets; for(let i=0;i<50;i++){ try{ targets=JSON.parse(await get("http://127.0.0.1:9333/json")); break;}catch(e){ await new Promise(r=>setTimeout(r,200)); } }
  const ws = targets.find(t=>t.type==="page").webSocketDebuggerUrl; const u=new URL(ws);
  const sock = net.connect(u.port, u.hostname); const key=crypto.randomBytes(16).toString("base64");
  sock.write(`GET ${u.pathname} HTTP/1.1\r\nHost: ${u.host}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ${key}\r\nSec-WebSocket-Version: 13\r\n\r\n`);
  let buf=Buffer.alloc(0), up=false, id=0; const pending={};
  function send(method, params){ const i=++id; const s=Buffer.from(JSON.stringify({id:i,method,params:params||{}})); const mask=crypto.randomBytes(4);
    let h; if(s.length<126) h=Buffer.from([0x81,0x80|s.length]); else if(s.length<65536){h=Buffer.alloc(4);h[0]=0x81;h[1]=0x80|126;h.writeUInt16BE(s.length,2);} else {h=Buffer.alloc(10);h[0]=0x81;h[1]=0x80|127;h.writeUInt32BE(0,2);h.writeUInt32BE(s.length,6);}
    const m=Buffer.alloc(s.length); for(let k=0;k<s.length;k++) m[k]=s[k]^mask[k%4]; sock.write(Buffer.concat([h,mask,m])); return new Promise(r=>pending[i]=r); }
  sock.on("data",d=>{ buf=Buffer.concat([buf,d]); if(!up){ const e=buf.indexOf("\r\n\r\n"); if(e<0)return; buf=buf.slice(e+4); up=true; start(); }
    for(;;){ if(buf.length<2)return; let len=buf[1]&127, off=2; if(len===126){ if(buf.length<4)return; len=buf.readUInt16BE(2); off=4;} else if(len===127){ if(buf.length<10)return; len=buf.readUInt32BE(6); off=10;}
      if(buf.length<off+len)return; const payload=buf.slice(off,off+len); buf=buf.slice(off+len);
      try{ const m=JSON.parse(payload.toString()); if(m.id&&pending[m.id]){pending[m.id](m.result||m.error);delete pending[m.id];}
        else if(m.method==="Runtime.consoleAPICalled"){ const t=m.params.args.map(a=>a.value||a.description||"").join(" "); if(!/keys:|flags:|mouse:|e\.g\.|down and|base=|checkout|hitboxes|sticks|ai=engine|^mini-soldat|^\s/.test(t)) console.log("console:",t.slice(0,300)); }
        else if(m.method==="Runtime.exceptionThrown"){ console.log("EXCEPTION", JSON.stringify(m.params.exceptionDetails).slice(0,600)); } }catch(e){} } });
  async function start(){
    await send("Runtime.enable"); await send("Page.enable");
    await send("Page.addScriptToEvaluateOnNewDocument",{source:`
      window.__frames=0; window.__urls=0; window.__urlms=0; window.__long=[];
      const raf=window.requestAnimationFrame.bind(window); let last=performance.now();
      window.requestAnimationFrame=function(f){ return raf(function(t){ const a=performance.now(); f(t); const b=performance.now(); window.__frames++; if(b-a>30) window.__long.push(Math.round(b-a)); }); };
      const td=HTMLCanvasElement.prototype.toDataURL; HTMLCanvasElement.prototype.toDataURL=function(){ const a=performance.now(); const r=td.apply(this,arguments); window.__urls++; window.__urlms+=performance.now()-a; return r; };`});
    await send("Page.navigate",{url});
    for(let s=1;s<=+process.argv[3];s++){ await new Promise(r=>setTimeout(r,1000));
      if(s===4){ await send("Input.dispatchKeyEvent",{type:"keyDown",key:" ",code:"Space",text:" ",windowsVirtualKeyCode:32}); await new Promise(r=>setTimeout(r,150)); await send("Input.dispatchKeyEvent",{type:"keyUp",key:" ",code:"Space",windowsVirtualKeyCode:32}); }
      if(s===6){ await send("Input.dispatchKeyEvent",{type:"keyDown",key:"d",code:"KeyD",text:"d",windowsVirtualKeyCode:68}); }
      const r=await Promise.race([send("Runtime.evaluate",{expression:"JSON.stringify({frames:window.__frames,pngs:window.__urls,png_ms:Math.round(window.__urlms),long:window.__long.splice(0).slice(0,12),images:document.getElementsByTagName('image').length})",returnByValue:true}), new Promise(r=>setTimeout(()=>r({timeout:true}),8000))]);
      console.log("t="+s+"s", r.timeout?"(page busy)":r.result&&r.result.value); }
    if(process.argv[4]){ const shot=await send("Page.captureScreenshot",{format:"png"}); require("fs").writeFileSync(process.argv[4], Buffer.from(shot.data,"base64")); }
    chrome.kill(); process.exit(0);
  }
})();
