function hash=JRDFileSHA256(filename)
fid=fopen(filename,'rb');
assert(fid>=0,'JRD:FileRead','Cannot read: %s',filename);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
end
