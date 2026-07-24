import { getApps, initializeApp } from "firebase-admin/app";
import { getAppCheck } from "firebase-admin/app-check";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getRemoteConfig } from "firebase-admin/remote-config";
import { getStorage } from "firebase-admin/storage";

const firebaseApp = getApps()[0] ?? initializeApp();

export const adminAuth = getAuth(firebaseApp);
export const adminAppCheck = getAppCheck(firebaseApp);
export const adminFirestore = getFirestore(firebaseApp);
export const adminMessaging = getMessaging(firebaseApp);
export const adminRemoteConfig = getRemoteConfig(firebaseApp);
export const adminStorage = getStorage(firebaseApp);
