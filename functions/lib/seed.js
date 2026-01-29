"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const app = (0, app_1.initializeApp)();
const db = (0, firestore_1.getFirestore)(app);
const users = [
    { uid: "demo-user-1", displayName: "Demo Chef 1", email: "demo1@example.com", role: "client" },
    { uid: "demo-user-2", displayName: "Demo Chef 2", email: "demo2@example.com", role: "client" },
    { uid: "demo-user-3", displayName: "Demo Chef 3", email: "demo3@example.com", role: "client" },
];
const sampleWords = ["pho", "banh mi", "bun bo", "com tam", "cha ca", "banh xeo", "mi quang", "hu tieu"];
const makeTokens = (text) => text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .split(/[^a-z0-9]+/)
    .filter((t) => t.length > 1);
const randomFrom = (arr) => arr[Math.floor(Math.random() * arr.length)];
const seedUsers = async (store) => {
    for (const user of users) {
        await store.collection("users").doc(user.uid).set({
            displayName: user.displayName,
            email: user.email,
            role: user.role,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            stats: { postCount: 0, recipeCount: 0, reactionCount: 0, commentCount: 0, shareCount: 0 },
        });
    }
    console.log("Seeded users");
};
const seedPosts = async (store) => {
    for (let i = 1; i <= 10; i++) {
        const authorId = users[i % users.length].uid;
        const title = `Demo Post ${i}: ${randomFrom(sampleWords)}`;
        const content = `This is demo post content number ${i}.`;
        await store.collection("posts").add({
            title,
            content,
            authorId,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            searchTokens: makeTokens(`${title} ${content}`),
            likeCount: 0,
            commentCount: 0,
            ratingCount: 0,
            shareCount: 0,
        });
    }
    console.log("Seeded posts");
};
const seedRecipes = async (store) => {
    for (let i = 1; i <= 10; i++) {
        const authorId = users[(i + 1) % users.length].uid;
        const title = `Demo Recipe ${i}: ${randomFrom(sampleWords)}`;
        const ingredients = ["rice", "pork", "fish sauce", "herbs"].slice(0, (i % 4) + 1);
        const steps = [`Prep ingredients for recipe ${i}`, `Cook step for recipe ${i}`, `Serve recipe ${i}`];
        await store.collection("recipes").add({
            title,
            ingredients,
            steps,
            authorId,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            ingredientsTokens: ingredients.map((ing) => ing.toLowerCase()),
            searchTokens: makeTokens(`${title} ${ingredients.join(" ")} ${steps.join(" ")}`),
            likeCount: 0,
            commentCount: 0,
            ratingCount: 0,
            shareCount: 0,
        });
    }
    console.log("Seeded recipes");
};
const seedChats = async (store) => {
    // DM chat between user1 and user2
    const now = firestore_1.FieldValue.serverTimestamp();
    const dmRef = await store.collection("chats").add({
        isGroup: false,
        type: "dm",
        name: null,
        photoUrl: null,
        memberIds: [users[0].uid, users[1].uid].sort(),
        adminIds: [users[0].uid, users[1].uid],
        createdAt: now,
        updatedAt: now,
        lastMessageAt: now,
        lastMessageText: "",
        lastMessageSenderId: null,
        mutedBy: [],
        nicknames: {},
        theme: null,
    });
    await dmRef.collection("messages").add({
        senderId: users[0].uid,
        type: "text",
        text: "Hello from demo user 1",
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        editedAt: null,
        deletedAt: null,
        reactions: {},
        readBy: { [users[0].uid]: firestore_1.FieldValue.serverTimestamp() },
        replyToMessageId: null,
        systemType: null,
    });
    await dmRef.collection("messages").add({
        senderId: users[1].uid,
        type: "text",
        text: "Hi there!",
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        editedAt: null,
        deletedAt: null,
        reactions: {},
        readBy: { [users[1].uid]: firestore_1.FieldValue.serverTimestamp() },
        replyToMessageId: null,
        systemType: null,
    });
    await dmRef.update({
        lastMessageText: "Hi there!",
        lastMessageSenderId: users[1].uid,
        lastMessageAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    // Group chat with all users
    const groupRef = await store.collection("chats").add({
        isGroup: true,
        type: "group",
        name: "Demo Group",
        memberIds: users.map((u) => u.uid),
        adminIds: [users[0].uid],
        photoUrl: null,
        createdAt: now,
        updatedAt: now,
        lastMessageAt: now,
        lastMessageText: "",
        lastMessageSenderId: null,
        createdBy: users[0].uid,
        mutedBy: [],
        nicknames: {},
        theme: null,
    });
    await groupRef.collection("messages").add({
        senderId: users[2].uid,
        type: "text",
        text: "Welcome to the demo group chat",
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        editedAt: null,
        deletedAt: null,
        reactions: {},
        readBy: { [users[2].uid]: firestore_1.FieldValue.serverTimestamp() },
        replyToMessageId: null,
        systemType: null,
    });
    await groupRef.update({
        lastMessageText: "Welcome to the demo group chat",
        lastMessageSenderId: users[2].uid,
        lastMessageAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    console.log("Seeded chats");
};
const main = async () => {
    await seedUsers(db);
    await seedPosts(db);
    await seedRecipes(db);
    await seedChats(db);
    console.log("Seeding completed.");
};
main()
    .then(() => {
    console.log("Done.");
    process.exit(0);
})
    .catch((err) => {
    console.error("Seeding failed", err);
    process.exit(1);
});
//# sourceMappingURL=seed.js.map