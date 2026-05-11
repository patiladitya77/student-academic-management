importScripts(
  "https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js",
);

firebase.initializeApp({
  apiKey: "AIzaSyAK4SuQEn0W0Ongyz9bFKpWZkyUjTICKL0",
  authDomain: "student-academic-management.firebaseapp.com",
  projectId: "student-academic-management",
  storageBucket: "student-academic-management.firebasestorage.app",
  messagingSenderId: "272496741788",
  appId: "1:272496741788:web:b53811400b66a30b424c59",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Background message received:", payload);
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
  });
});
