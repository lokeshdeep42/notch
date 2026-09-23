/**
 * Sill waitlist → Google Sheets.
 *
 * Bound script: open the spreadsheet, Extensions → Apps Script, paste this file, run `setup` once,
 * then Deploy → New deployment → Web app (Execute as: Me, Who has access: Anyone).
 * Put the /exec URL in WAITLIST_ENDPOINT in site/index.html. Full steps: site/README.md.
 */

const SHEET_NAME = 'Waitlist';
const HEADERS = ['Timestamp', 'Name', 'Email', 'Used before', 'Source', 'Referrer'];
const EMAIL_COLUMN = 3;
const MAX_LENGTH = { name: 100, email: 254, tried: 40, source: 100, referrer: 500 };
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Receives the landing page form (application/x-www-form-urlencoded). */
function doPost(e) {
  const p = (e && e.parameter) || {};

  // Honeypot: people never see this field, bots fill it. Answer "ok" so they move on.
  if (p.company) return json_({ ok: true });

  const name = clean_(p.name, MAX_LENGTH.name);
  const email = clean_(p.email, MAX_LENGTH.email).toLowerCase();
  if (!name) return json_({ ok: false, error: 'missing_name' });
  if (!EMAIL_RE.test(email)) return json_({ ok: false, error: 'invalid_email' });

  const lock = LockService.getScriptLock();
  try {
    lock.waitLock(10000);
  } catch (err) {
    return json_({ ok: false, error: 'busy' });
  }

  try {
    const sheet = sheet_();
    const lastRow = sheet.getLastRow();
    if (lastRow > 1) {
      const existing = sheet
        .getRange(2, EMAIL_COLUMN, lastRow - 1, 1)
        .createTextFinder(email)
        .matchEntireCell(true)
        .findNext();
      if (existing) return json_({ ok: true, duplicate: true });
    }

    sheet.appendRow([
      new Date(),
      text_(name),
      text_(email),
      text_(clean_(p.tried, MAX_LENGTH.tried)),
      text_(clean_(p.source, MAX_LENGTH.source)),
      text_(clean_(p.referrer, MAX_LENGTH.referrer)),
    ]);
    return json_({ ok: true });
  } finally {
    lock.releaseLock();
  }
}

/** Open the /exec URL in a browser to check the deployment is live. */
function doGet() {
  return json_({ ok: true, service: 'sill-waitlist' });
}

/** Run once from the editor: creates the sheet, header row and formatting. */
function setup() {
  const sheet = sheet_();
  sheet.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]).setFontWeight('bold');
  sheet.setFrozenRows(1);
  sheet.getRange('A:A').setNumberFormat('yyyy-mm-dd hh:mm:ss');
  sheet.autoResizeColumns(1, HEADERS.length);
}

function sheet_() {
  const book = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = book.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = book.insertSheet(SHEET_NAME);
    sheet.appendRow(HEADERS);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function clean_(value, max) {
  return String(value || '').replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, max);
}

// Anything starting with = + - @ would run as a formula when the sheet opens. A leading
// apostrophe makes Sheets store it as plain text (the apostrophe itself is not shown).
function text_(value) {
  return /^[=+\-@]/.test(value) ? "'" + value : value;
}

function json_(body) {
  return ContentService.createTextOutput(JSON.stringify(body)).setMimeType(ContentService.MimeType.JSON);
}
