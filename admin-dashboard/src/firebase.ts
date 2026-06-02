
import { initializeApp } from "firebase/app";
import { getAuth, connectAuthEmulator } from "firebase/auth";
import { getFirestore, connectFirestoreEmulator } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyAKEqTR0yFT27UxlneOQNbsKFebqwlj2nY",
  authDomain: "bookedmic-1cf9d.firebaseapp.com",
  projectId: "bookedmic-1cf9d",
  storageBucket: "bookedmic-1cf9d.appspot.com",
  messagingSenderId: "1049808440381",
  appId: "1:1049808440381:web:ef477a4bce25b9e070ee54",
  measurementId: "G-WTEGV15L7S"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

/*
if (window.location.hostname === "localhost") {
  connectAuthEmulator(auth, "http://localhost:9099");
  connectFirestoreEmulator(db, "localhost", 8080);
}
*/
