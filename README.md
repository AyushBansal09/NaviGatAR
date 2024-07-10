# Indoor AR Navigation

## Project Overview
This project is designed to facilitate indoor navigation using augmented reality (AR) technology on mobile devices. It leverages both ARCore (Android) and ARKit (iOS) to provide a robust AR experience.

## Stack

- Flutter
- ARCore/ARKit
- Node.js
- PostgreSQL
- Prisma

## Prerequisites

Before you begin, ensure that the following tools are installed on your system:
- Flutter
- Node.js
- PostgreSQL
- Prisma

Additionally, this project currently supports debugging through a physical connection (wired or wireless) between the PC and a mobile device.

## Environment Setup

### Database Setup

1. **Migrate the database locally:**
   Navigate to the Prisma folder and deploy the migrations:


   ```cd backend/prisma```


   ```npx prisma migrate deploy```

### Backend Setup

2. **Run the backend:**
   Navigate to the backend folder, install dependencies, build the project, and start the server:


   ```cd backend```


   ```npm install```


   ```npm run build```


   ```npm run start```



### Frontend Setup

3. **Run the frontend:**
   Navigate to the frontend directory and start the Flutter app. Make sure your device is connected for debugging:


   ```cd frontend```

   
   ```flutter run```


## Debugging

To debug the application, you will need to set up your mobile device for debugging connected to your PC. Follow these guides to enable debugging options on your device:

- **Android Studio Debugging:**
- [Configure On-device Developer Options](https://developer.android.com/studio/debug/dev-options)
- [Set Up Wireless Debugging](https://developer.android.com/studio/command-line/adb#wireless)

- **Xcode Debugging: (Recommended)** 
- [Launch Your App on a Device](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device)
- [Wireless Debugging in Xcode](https://help.apple.com/xcode/mac/current/#/dev60b6fbbc7)

Ensure you follow these instructions to properly prepare your device for a debugging session with your PC.
