const CANON=['Studio Backup','Unterwegs','Zoom H6-01','NAS Klon','Hochzeitsvideos Archiv','Masterarbeit Backup','Daten I','EOS_R5'];
const OFFLINE=new Set(['Hochzeitsvideos Archiv','Masterarbeit Backup','Daten I','EOS_R5']);
const nameOf=r=>CANON.find(c=>r.includes('>'+c+'<'));
const isSel=r=>/font-weight:600; background:(var\(--color-text\)|var\(--di-sel\)|oklch\([^)]*\)); color:#fff/.test(r);
const svgOf=r=>(r.match(/<svg viewBox="0 0 256 256" width="15"[\s\S]*?<\/svg>/)||[''])[0];
function plainRow(tpl,name,svg){
  let r=tpl.replace(/<svg viewBox="0 0 256 256" width="15"[\s\S]*?<\/svg>/,svg.replace('fill="currentColor"','fill="var(--color-text)"'));
  const n=nameOf(r);r=r.split('>'+n+'<').join('>'+name+'<').split('title="'+n+'"').join('title="'+name+'"');
  r=r.replace(/ opacity:\.4;/,'').replace(/ data-comment-anchor="[^"]*"/g,'');
  if(OFFLINE.has(name))r=r.replace('gap:8px; border-radius','gap:8px; opacity:.4; border-radius');
  if(!/margin-bottom:3px/.test(r))r=r.replace('style="padding:7px 10px;','style="padding:7px 10px; margin-bottom:3px;');
  return r;
}
function selRow(tpl,name,svg){
  let r=svg?tpl.replace(/<svg viewBox="0 0 256 256" width="15"[\s\S]*?<\/svg>/,svg.replace('fill="var(--color-text)"','fill="currentColor"')):tpl;
  const n=nameOf(r);r=r.split('>'+n+'<').join('>'+name+'<').split('title="'+n+'"').join('title="'+name+'"');
  if(!/margin-bottom:3px/.test(r))r=r.replace('style="padding:7px 10px;','style="padding:7px 10px; margin-bottom:3px;');
  return r;
}
// L: lines array; selFor(lineIndex) -> name or null (keep)
function normSidebars(L,selFor){
  let count=0;
  for(let i=L.length-1;i>=0;i--){
    if(!L[i].includes('>ALLE SPEICHERMEDIEN<'))continue;
    let j=i+1;const idx=[];while(L[j]&&L[j].includes('finder-hover-row')&&nameOf(L[j])){idx.push(j);j++}
    if(!idx.length)continue;
    const rows={};idx.forEach(k=>rows[nameOf(L[k])]=L[k]);
    const curSel=idx.map(k=>L[k]).find(isSel);
    const want=(selFor&&selFor(i))||(curSel&&nameOf(curSel));
    const plainTpl=idx.map(k=>L[k]).find(r=>!isSel(r)&&!/ opacity:\.4;/.test(r)&&!/title="/.test(r.split('eject-ico-btn')[1]||'')&&r.includes('<span style="flex:1;">'))||idx.map(k=>L[k]).find(r=>!isSel(r));
    const longTpl=idx.map(k=>L[k]).find(r=>/<span title="/.test(r)&&!isSel(r));
    const out=CANON.map(n=>{
      const own=rows[n]||plainTpl;const svg=svgOf(own)||svgOf(plainTpl);
      if(n===want&&curSel)return selRow(curSel,n,svg);
      const tpl=(n==='Hochzeitsvideos Archiv'&&longTpl)?longTpl:plainTpl;
      return plainRow(tpl,n,svg);
    });
    L.splice(idx[0],idx.length,...out);count++;
  }
  return count;
}
module.exports={normSidebars,CANON,OFFLINE};
