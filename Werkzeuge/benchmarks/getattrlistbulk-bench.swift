import Foundation
let dir = CommandLine.arguments[1]
func t<T>(_ name:String,_ f:()->T)->T{let s=DispatchTime.now();let r=f();let ms=Double(DispatchTime.now().uptimeNanoseconds-s.uptimeNanoseconds)/1e6;print(String(format:"%-34@ %8.0f ms",name as NSString,ms));return r}
let url=URL(fileURLWithPath:dir,isDirectory:true)
let keys:[URLResourceKey]=[.isDirectoryKey,.isPackageKey,.isSymbolicLinkKey,.isHiddenKey,.fileSizeKey,.contentModificationDateKey]
// 1) wie die App heute: contentsOfDirectory + resourceValues je Datei
let skipFM = CommandLine.arguments.count>2
let n1 = skipFM ? 0 : t("FileManager+resourceValues(6 keys)"){()->Int in let u=(try? FileManager.default.contentsOfDirectory(at:url,includingPropertiesForKeys:keys,options:[])) ?? []; var c=0; for i in u{ _ = try? i.resourceValues(forKeys:Set(keys)); c+=1}; return c}
// 2) nur Namen
let n2 = skipFM ? 0 : t("FileManager nur Namen"){ (try? FileManager.default.contentsOfDirectory(atPath:dir).count) ?? 0 }
// 3) getattrlistbulk: Name, Typ, Größe, Änderungsdatum
let n3=t("getattrlistbulk (name,type,size,mtime)"){()->Int in
  let fd=open(dir,O_RDONLY); if fd<0{return -1}; defer{close(fd)}
  var al=attrlist(); al.bitmapcount=UInt16(ATTR_BIT_MAP_COUNT)
  al.commonattr=attrgroup_t(ATTR_CMN_RETURNED_ATTRS)|attrgroup_t(ATTR_CMN_NAME)|attrgroup_t(ATTR_CMN_OBJTYPE)|attrgroup_t(ATTR_CMN_MODTIME)
  al.fileattr=attrgroup_t(ATTR_FILE_DATALENGTH)
  let bufSize=256*1024; let buf=UnsafeMutableRawPointer.allocate(byteCount:bufSize,alignment:8); defer{buf.deallocate()}
  var count=0
  while true{
    let r=getattrlistbulk(fd,&al,buf,bufSize,UInt64(FSOPT_PACK_INVAL_ATTRS))
    if r<=0{break}
    var p=buf
    for _ in 0..<Int(r){ let len=p.load(as:UInt32.self); count+=1; p=p.advanced(by:Int(len)) }
  }
  return count}
print("Einträge: FM=\(n1) Namen=\(n2) bulk=\(n3)")
