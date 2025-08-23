# T[root]H Frontend (Flutter)

T[root]H is a spiritually rooted mentorship and assessment platform designed to guide apprentices and empower mentors through custom assessments, coaching tools, and secure communication. This is the official Flutter frontend application built with Firebase integration.

---

## 🌟 Vision

A bold, clean, and spiritually warm application that empowers discipleship by:
- Providing AI-scored spiritual assessments
- Tracking spiritual growth over time
- Enabling mentor-apprentice relationships
- Supporting a mobile-first, user-friendly design with a modern aesthetic

---

## 🧱 Tech Stack

- **Flutter** (for cross-platform mobile/web UI)
- **Firebase**
  - Firebase Auth (authentication)
  - Firestore (user onboarding status, role)
  - Firebase Hosting (web app hosting)
- **Dart** (programming language)
- **Poppins** and **Unkempt** fonts
- **SendGrid** (email service via backend)
- **Custom backend API** built with FastAPI

---

## 🎨 Visual & UX Style

- **Theme**: Black, gold, grey, and white
- **Font**: [Unkempt (logo)](https://fonts.google.com/specimen/Unkempt), [Poppins (app text)](https://fonts.google.com/specimen/Poppins)
- **Splash Screen**: Black/gold mesh background with centered **T[root]H** logo and subtext `#getrooted`
- **Design Style**: Clean layout, centered AppBar titles, elevated buttons, rounded cards, subtle icons

---

## 🚀 Features & Requirements

### ✅ Authentication
- Firebase email/password login & signup
- FirebaseAuth persistence
- Role assignment (mentor, apprentice) during onboarding
- Firebase Firestore stores `onboarded` and `role` fields

### ✅ Onboarding
- First-time users are prompted to choose their role
- Data is saved to Firestore
- Users are routed to role-specific dashboards after onboarding

### ✅ Dashboards
- **MentorDashboard**: Access to apprentices, assessments, notes, history
- **ApprenticeDashboard**: Access to own assessments and feedback

### ✅ Splash Screen
- Custom splash image
- Logo: `T[root]H` in Unkempt
- Tagline: `#getrooted`

### ✅ Logout
- Visible logout button in AppBar for both dashboards
- Confirmation dialog before logout

---

## 📁 Folder Structure (simplified)

