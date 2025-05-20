# App Icon and Splash Screen Integration Guide

This guide will help you integrate your app icon and splash screen into the Flutter project.

## Step 1: Copy the Image Files

Copy your image files to the project's asset directory:

```
# Create the images directory if it doesn't exist yet
mkdir -p /home/daniel/work/puzzgameFlutter/assets/images

# Copy the app icon
cp /home/daniel/puzzgameFlutter/assets/app_icon-512.png /home/daniel/work/puzzgameFlutter/assets/images/

# Copy the splash screen
cp /home/daniel/puzzgameFlutter/assets/splashscreen-portrait.png /home/daniel/work/puzzgameFlutter/assets/images/
```

## Step 2: Install Required Dependencies

Install the dependencies for app icon and splash screen generation:

```
cd /home/daniel/work/puzzgameFlutter
flutter pub get
```

## Step 3: Generate App Icons

Run the flutter_launcher_icons package to generate app icons for both Android and iOS:

```
flutter pub run flutter_launcher_icons
```

This command will:
- Create icons of various sizes for Android and iOS
- Update the necessary Android and iOS configuration files
- Set up adaptive icons for Android

## Step 4: Generate Splash Screen

Run the flutter_native_splash package to generate the splash screen:

```
flutter pub run flutter_native_splash:create
```

This command will:
- Create splash screen resources for Android and iOS
- Update the necessary configuration files
- Set up the splash screen display behavior

## Step 5: Test Your App

Build and run your app to see the new app icon and splash screen:

```
flutter run
```

## Troubleshooting

If you encounter any issues:

1. Ensure the image files are in the correct location
2. Check that the pubspec.yaml file has the correct asset paths
3. Try cleaning the project with `flutter clean` and then run the generation commands again
4. For Android, make sure the adaptive icon settings are properly configured
5. For iOS, ensure the image meets the required specifications

## Next Steps

After successfully integrating the app icon and splash screen, you might want to:

1. Customize the splash screen behavior (duration, transition)
2. Add custom colors or background to the splash screen
3. Implement initialization logic during the splash screen display
