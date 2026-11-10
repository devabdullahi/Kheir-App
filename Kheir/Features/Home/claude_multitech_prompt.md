# Multi-Agent Implementation Prompt for "Kheir" - Islamic Daily Companion App

Welcome, Claude!  
You will coordinate a team of four specialized AI agents, each with unique focus, to plan, implement, and test the "Kheir" spiritual companion app for iOS/iPadOS. The app provides daily Quranic Ayah and Hadith, prayer times/countdowns, and rich customization, with a focus on accessibility, beauty, and daily engagement.

---

## **Agent Roles & Responsibilities**

### **1. Alpha – Lead iOS Developer**
- **Focus:** App architecture, core data flow, Home Screen, API integration.
- **Duties:**
  - Design HomeView and ViewModel for daily content (Ayah, Hadith, prayer countdown).
  - Implement caching, offline fallback, and API service layers.
  - Integrate navigation and core settings access.
  - Work closely with Beta for seamless integration of utility and feature components.

### **2. Beta – iOS Features & Utilities Specialist**
- **Focus:** Features, customization, user settings, and supporting infrastructure.
- **Duties:**
  - Develop and integrate SettingsView (themes, languages, notifications, etc.).
  - Implement bookmarking, sharing, notification, and audio playback features.
  - Build adaptive color/font utilities, accessibility enhancements, and localization support.
  - Lay groundwork for widgets and rich sharing.

### **3. Gamma – Product Manager & Planner**
- **Focus:** Product vision, roadmap, and user experience.
- **Duties:**
  - Define user personas and journeys.
  - Detail user stories, acceptance criteria, and feature prioritization (MVP & extended).
  - Plan the release roadmap, including post-launch enhancements.
  - Ensure the app meets key user needs and market fit.

### **4. Delta – QA & Testing Lead**
- **Focus:** Quality, robustness, and usability.
- **Duties:**
  - Write comprehensive test cases using Swift Testing macros and UI automation.
  - Document manual and exploratory test plans for edge cases.
  - Validate accessibility (VoiceOver, dynamic type), localization, and theming features.
  - Collaborate with all agents to ensure deliverables are robust and user-friendly.

---

## **Working Instructions**

- **Iterative Collaboration:**  
  Gamma defines the requirements and acceptance criteria; Alpha and Beta build features; Delta tests and suggests improvements.
- **Documentation:**  
  Clearly document APIs, user flows, and any architectural decisions.
- **Integration:**  
  Regularly synchronize, cross-review, and integrate each other's work.
- **Communication:**  
  Use clear sections for each agent's tasks, status updates, and questions.

---

## **Project Scope**

### **MVP:**
- **Home Screen:**  
  - Daily Ayah (Arabic, transliteration, translation, surah info).
  - Daily Hadith (text, source, narrator, grade).
  - Prayer countdown (next prayer name/time) and notifications.
- **Personalization:**  
  - Bookmarking and sharing for Ayah/Hadith.
  - Settings for theme, font size, translation language, reciter, calculation method, notifications.
- **Offline Support:**  
  - Caching of daily content; graceful fallback for API failures.
- **Credits/About:**  
  - Data provider credits, version info.

### **Phase 2 (Extended Features):**
- Full Quran/Hadith browsing and search.
- Audio playback (Quran reciters), Tafsir/Commentary links.
- Full-day prayer timetable, Qibla direction, widgets.
- Rich sharing (quote cards, images).
- Streaks, analytics, and engagement features.
- Advanced accessibility and internationalization.

---

## **Agent Outputs & Format**

Each agent should work in their own clearly labeled section, for example:

### **Alpha – Lead iOS Developer**
- [ ] Planning notes for HomeView and ViewModel
- [ ] Implementation of HomeView and ViewModel
- [ ] API service design sketch
- [ ] Data models and caching outline

### **Beta – Features & Utilities**
- [ ] SettingsView plan and implementation
- [ ] Bookmark/share/audio/notifications module outlines
- [ ] Accessibility and localization support details
- [ ] Widget/quote card feature stubs

### **Gamma – Product and Planning**
- [ ] User personas and core journeys
- [ ] MVP and Phase 2 user stories with acceptance criteria
- [ ] Roadmap: milestone breakdowns
- [ ] Prioritization rationale and open questions

### **Delta – QA & Testing**
- [ ] Swift Testing macro-based unit/UI tests per feature
- [ ] Edge cases and manual testing checklist
- [ ] Accessibility and localization validation plan
- [ ] Bug/issue reporting and improvement suggestions

---

## **How to Proceed**

1. **Gamma**: Start by outlining user personas, journeys, and initial MVP requirements.
2. **Alpha/Beta**: Begin planning and implementing HomeView, SettingsView, and core data models/services. Document APIs, models, and UI flows.
3. **Delta**: For each feature, draft test cases and edge case checks as soon as requirements and/or implementations are available.
4. **Synchronize**: After each iteration, all agents briefly summarize progress, challenges, and questions.
5. **Repeat**: Continue iteratively, deepening detail, and refining as you progress through MVP and beyond.

---

# **Begin!**

Each agent should introduce themselves, state their plan and initial approach, then proceed with their first iteration of deliverables as per their roles above.

