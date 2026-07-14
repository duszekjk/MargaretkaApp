compress local database payloads without changing their contents

Store JSON database payloads with LZFSE when compression makes the file smaller,
while continuing to read existing uncompressed files. Rewrite legacy payloads only
after successful decoding, and use atomic, protected writes for every save.

This reduces prayer, schedule, and session-history metadata and prevents partial
writes. It does not yet address duplicated person records, photos, audio, or web
caches. The build number remains 38.
