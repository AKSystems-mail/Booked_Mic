const admin = require('firebase-admin');

admin.initializeApp({
  projectId: 'bookedmic-1cf9d'
});

const uid = 'MdtCAmyY5rXkCmg05EcscjbYv1w2';
const newPassword = '104tenfour';

admin.auth().updateUser(uid, {
  password: newPassword
})
  .then((userRecord) => {
    console.log('Successfully updated user', userRecord.uid);
    process.exit(0);
  })
  .catch((error) => {
    console.error('Error updating user:', error);
    process.exit(1);
  });
