# 🦖 DINO Browser: The Future of Mobile Web

> **DINO Browser** is not just a tool; it's a high-performance browsing experience. Engineered with Flutter, it blends futuristic aesthetics with revolutionary features like **T-Rex Vision** and **Workspaces

![Version](https://img.shields.io/badge/version-1.0.0--beta-green?style=for-the-badge)
![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)

---

## ✨ Why DINO?

- **🚀 Cosmic UI/UX**: Step into the future with a design language featuring glassmorphism, fluid animations, and a laser-focused dark mode.
- **👀 T-Rex Vision (Split Screen)**: Multitasking evolved. Watch videos or read documentation while browsing a second site simultaneously with our draggable divider.
- **🛡️ Raptor Mode**: Ghost-level privacy. Browse securely with an isolated session that leaves no trace.
- **📦 Workspaces**: Zero clutter. Organize your digital life into logical silos like *Work*, *Personal*, or *Gaming*.
- **🤖 Dino AI**: Your native AI companion. Summarize long-form content, ask complex questions, or generate creative ideas without leaving the tab.

## 🛠️ The Engine Under the Hood

DINO combines industry-standard mobile tech with a custom backend for extension support.

- **Frontend**: Flutter & Dart (UI/Logic)
- **Web Core**: `flutter_inappwebview`
- **Extensions & Add-ons**: 
  - **Domain**: `bilalcode.site` (Dedicated Extension API)
  - **Storage**: MySQL Database for extension management
- **Backend Services**: 
  - **Firebase Auth**: Secure User Management
  - **SQLite**: Lightning-fast local persistence via `sqflite`
- **Visuals**: `animate_do` for micro-interactions

---

## 🚀 Rapid Setup Guide

### 1. Prerequisites
- Flutter SDK (Latest Stable)
- Android Studio / VS Code
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) installed

### 2. Installation
```bash
git clone https://github.com/dinorexy007/dinobrowser.git
cd dinobrowser
flutter pub get
```

### 3. Firebase Configuration
To get Auth and Cloud features running:
1. **Create a Project** in the [Firebase Console](https://console.firebase.google.com/).
2. **Configure with FlutterFire**:
   ```bash
   flutterfire configure
   ```
   *This automatically creates the apps and places the necessary config files.*
3. **Enable Authentication**:
   - Go to your Project in Firebase Console -> **Build** -> **Authentication**.
   - Enable your preferred Sign-in methods (Google, Email/Password, etc.).

### 4. Ignite
```bash
flutter run
```

---

## 🦖 Early Access & Feedback

This is **Version 1.0 (Early Access)**. While we've worked hard to make it solid, some fossils (bugs) might still be lurking!

We value your feedback to help DINO evolve. If you encounter issues or have a genius feature idea:
- 📲 **In-App**: Navigate to `Settings -> Feedback`
- 📧 **Direct Email**: [hhdinorexy@gmail.com](mailto:hhdinorexy@gmail.com)

---
*Built with passion, speed, and a touch of prehistoric power.* 🦖
