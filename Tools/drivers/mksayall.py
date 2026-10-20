# SPDX-License-Identifier: GPL-3.0-or-later
import zipfile, html, sys
p1 = "Training programmes shall combine theoretical and practical training to develop the technical and behavioural competencies of assessors. Each training programme shall specify the number of assessors targeted, the timeframe for implementation, and the objectives of the training programme. These variables shall be reflected in the approved training programme development form."
p2 = "A training programme for the preparation and qualification of assessors shall be conducted every three years or whenever necessary. The number of candidates shall be determined in accordance with the assessors’ matrix, with each programme targeting between 20 and 25 trainees across both its theoretical and practical components."
long = " ".join([p1, p2, p1])
paras = [p1, p2] * 6 + [long, long] + [p1, p2] * 4
body = ''.join(f'<w:p><w:r><w:t xml:space="preserve">{html.escape(t)}</w:t></w:r></w:p>' for t in paras)
doc = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>'
       + body + '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>')
ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'
rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'
with zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('[Content_Types].xml', ct); z.writestr('_rels/.rels', rels); z.writestr('word/document.xml', doc)
