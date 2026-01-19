const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');

const db = admin.firestore();

async function submitIssueReport({ uid, email, message }) {
  const id = uuidv4();
  const createdAt = new Date().toISOString();
  await db.collection('issueReports').doc(id).set({
    id,
    uid,
    email,
    message,
    createdAt,
  });
  return { success: true, id };
}

async function getAllIssueReports() {
  const snap = await db.collection('issueReports').orderBy('createdAt', 'desc').get();
  return snap.docs.map(doc => doc.data());
}

module.exports = { submitIssueReport, getAllIssueReports };

