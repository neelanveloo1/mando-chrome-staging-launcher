import {get, put} from '@vercel/blob';
import {hash, isToken, cleanReport} from '../lib/status.mjs';
export default async function handler(req, res) {
  res.setHeader('Cache-Control', 'private, no-store');
  if (!['GET','POST'].includes(req.method)) return res.status(405).json({error:'Method not allowed'});
  const token = (req.headers.authorization || '').replace(/^Bearer /, '');
  if (!isToken(token)) return res.status(401).json({error:'Open your private status link from Mando Chrome.'});
  if (!process.env.BLOB_READ_WRITE_TOKEN) return res.status(503).json({error:'Status storage is not configured.'});
  const key = `devices/${hash(req.method === 'POST' ? hash(token) : token)}.json`;
  try {
    if (req.method === 'POST') {
      if (Number(req.headers['content-length'] || 0) > 4096) return res.status(413).json({error:'Report too large'});
      let body = req.body;
      if (typeof body === 'string') { if (body.length > 4096) return res.status(413).end(); body = JSON.parse(body); }
      if (JSON.stringify(body || {}).length > 4096) return res.status(413).end();
      let report;
      try { report = cleanReport(body); } catch { return res.status(400).json({error:'Invalid report'}); }
      await put(key, JSON.stringify(report), {access:'private', addRandomSuffix:false, allowOverwrite:true, contentType:'application/json', cacheControlMaxAge:0});
      return res.status(200).json({ok:true, receivedAt:report.receivedAt});
    }
    const blob = await get(key, {access:'private', useCache:false});
    if (!blob || !blob.stream) return res.status(404).json({error:'Waiting for this Mac’s first report. The monitor checks every two minutes.'});
    const report = JSON.parse(await new Response(blob.stream).text());
    return res.status(200).json(report);
  } catch { return res.status(503).json({error:'Unable to read or save status. Try again shortly.'}); }
}
