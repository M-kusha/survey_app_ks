importScripts(
  'https://www.gstatic.com/firebasejs/12.17.0/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/12.17.0/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyCHESrdF3ty1DKz7guTv1QzBnC6fZ87q6M',
  appId: '1:1005316799898:web:75aae15cc70210fcc98e23',
  messagingSenderId: '1005316799898',
  projectId: 'echomeet-app',
  authDomain: 'echomeet-app.firebaseapp.com',
  storageBucket: 'echomeet-app.firebasestorage.app',
});

firebase.messaging();
