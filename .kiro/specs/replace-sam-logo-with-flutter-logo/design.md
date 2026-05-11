# Replace SAM Logo with Flutter Logo Bugfix Design

## Overview

The splash screen currently displays a custom SAM logo (Image.asset('assets/images/Splash1.png')) instead of the default Flutter logo. This bugfix will replace the Image.asset widget with the FlutterLogo widget while preserving all other splash screen functionality including the blue background, circular container dimensions, "from Group 1" text, and the 3-second navigation timer.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug - when the splash screen renders with a custom SAM logo instead of the Flutter logo
- **Property (P)**: The desired behavior when the splash screen is displayed - the Flutter logo should be shown in the circular container
- **Preservation**: Existing splash screen behavior that must remain unchanged: blue background, circular container dimensions (150x150), "from Group 1" text, 3-second timer, and navigation logic
- **SplashScreen**: The StatefulWidget in `lib/splashscreen.dart` that displays the initial screen when the app launches
- **Image.asset**: The current widget displaying 'assets/images/Splash1.png' that needs to be replaced
- **FlutterLogo**: The Flutter framework widget that displays the standard Flutter logo

## Bug Details

### Bug Condition

The bug manifests when the splash screen is rendered. The `SplashScreen` widget's build method uses `Image.asset('assets/images/Splash1.png')` to display a custom SAM logo instead of using the `FlutterLogo` widget to display the standard Flutter logo.

**Formal Specification:**

```
FUNCTION isBugCondition(input)
  INPUT: input of type SplashScreenRenderContext
  OUTPUT: boolean

  RETURN input.isRenderingSplashScreen == true
         AND input.logoWidget IS Image.asset
         AND input.logoWidget.assetPath == 'assets/images/Splash1.png'
         AND input.logoWidget IS NOT FlutterLogo
END FUNCTION
```

### Examples

- **Current (Defect)**: When the app launches, the splash screen displays a custom SAM logo image loaded from assets/images/Splash1.png in a 150x150 circular container
- **Expected (Correct)**: When the app launches, the splash screen should display the Flutter logo using the FlutterLogo widget in a 150x150 circular container
- **Edge Case**: The circular container dimensions (150x150) and ClipOval wrapper should remain unchanged regardless of which logo is displayed

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**

- The blue background (Colors.blue) must continue to be displayed
- The "from Group 1" text at the bottom must remain unchanged in position, styling, and content
- The 3-second timer that triggers navigation must continue to work exactly as before
- The navigation logic based on user authentication state must remain unchanged
- The circular container with ClipOval and 150x150 dimensions must remain unchanged
- The overall layout with Stack, Align widgets, and positioning must remain unchanged

**Scope:**
All aspects of the splash screen that do NOT involve the logo image itself should be completely unaffected by this fix. This includes:

- Background color and styling
- Text content and positioning
- Timer functionality and duration
- Navigation logic and routing
- Firebase authentication checks
- Layout structure and widget hierarchy (except the logo widget replacement)

## Hypothesized Root Cause

Based on the bug description, the root cause is straightforward:

1. **Incorrect Widget Choice**: The developer used `Image.asset('assets/images/Splash1.png')` to display a custom logo instead of using the built-in `FlutterLogo` widget
   - The Image.asset widget loads a custom asset file
   - The FlutterLogo widget is the standard Flutter framework widget for displaying the Flutter logo

2. **No Technical Complexity**: This is not a logic error or timing issue - it's simply using the wrong widget for the logo display

## Correctness Properties

Property 1: Bug Condition - Flutter Logo Display

_For any_ splash screen render where the app is launching, the fixed SplashScreen widget SHALL display the Flutter logo using the FlutterLogo widget instead of the custom SAM logo image, while maintaining the circular container with 150x150 dimensions.

**Validates: Requirements 2.1**

Property 2: Preservation - Splash Screen Functionality

_For any_ splash screen render, the fixed code SHALL preserve all existing functionality including the blue background, "from Group 1" text display, 3-second navigation timer, authentication-based routing logic, and overall layout structure.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4**

## Fix Implementation

### Changes Required

**File**: `lib/splashscreen.dart`

**Function**: `_SplashScreenState.build`

**Specific Changes**:

1. **Replace Image.asset with FlutterLogo**: Replace the `Image.asset('assets/images/Splash1.png', fit: BoxFit.cover)` widget with `FlutterLogo(size: 150)`
   - Remove the Image.asset widget entirely
   - Add FlutterLogo widget with size parameter set to 150 to match the container dimensions
   - The FlutterLogo widget will automatically handle its own rendering and sizing

2. **Maintain Container Structure**: Keep the ClipOval and SizedBox wrapper structure
   - The ClipOval ensures the logo appears in a circular container
   - The SizedBox with height: 150 and width: 150 maintains the container dimensions
   - The FlutterLogo size: 150 parameter ensures the logo fits properly within the container

3. **No Other Changes**: All other code remains unchanged
   - Blue background stays as Colors.blue
   - "from Group 1" text and styling remain unchanged
   - Timer duration stays at 3 seconds
   - Navigation logic remains unchanged
   - All imports, state management, and Firebase logic remain unchanged

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, verify the current defect exists (SAM logo is displayed), then verify the fix works correctly (Flutter logo is displayed) and preserves all existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Confirm the bug exists BEFORE implementing the fix by verifying that the splash screen currently displays the SAM logo instead of the Flutter logo.

**Test Plan**: Run the app and visually inspect the splash screen to confirm it displays the custom SAM logo. Check the widget tree to verify Image.asset is being used. Run these observations on the UNFIXED code.

**Test Cases**:

1. **Visual Inspection Test**: Launch the app and observe that a custom SAM logo appears (will show SAM logo on unfixed code)
2. **Widget Tree Test**: Inspect the widget tree to confirm Image.asset('assets/images/Splash1.png') is present (will find Image.asset on unfixed code)
3. **Logo Type Test**: Verify that FlutterLogo widget is NOT present in the splash screen (will confirm absence on unfixed code)

**Expected Counterexamples**:

- The splash screen displays a custom SAM logo image instead of the Flutter logo
- The widget tree contains Image.asset instead of FlutterLogo

### Fix Checking

**Goal**: Verify that after the fix, the splash screen displays the Flutter logo correctly.

**Pseudocode:**

```
FOR ALL splashScreenRender WHERE isBugCondition(splashScreenRender) DO
  result := SplashScreen_fixed.build()
  ASSERT result.containsWidget(FlutterLogo)
  ASSERT result.flutterLogoSize == 150
  ASSERT NOT result.containsWidget(Image.asset('assets/images/Splash1.png'))
END FOR
```

### Preservation Checking

**Goal**: Verify that all non-logo aspects of the splash screen remain unchanged after the fix.

**Pseudocode:**

```
FOR ALL splashScreenRender DO
  originalBehavior := SplashScreen_original.getNonLogoBehavior()
  fixedBehavior := SplashScreen_fixed.getNonLogoBehavior()
  ASSERT originalBehavior.backgroundColor == fixedBehavior.backgroundColor
  ASSERT originalBehavior.textContent == fixedBehavior.textContent
  ASSERT originalBehavior.timerDuration == fixedBehavior.timerDuration
  ASSERT originalBehavior.navigationLogic == fixedBehavior.navigationLogic
  ASSERT originalBehavior.containerDimensions == fixedBehavior.containerDimensions
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:

- It generates many test cases automatically across different app states
- It catches edge cases that manual unit tests might miss (e.g., different authentication states)
- It provides strong guarantees that behavior is unchanged for all non-logo elements

**Test Plan**: Observe behavior on UNFIXED code first for background color, text display, timer, and navigation, then write property-based tests capturing that behavior.

**Test Cases**:

1. **Background Color Preservation**: Observe that blue background displays correctly on unfixed code, then verify it continues after fix
2. **Text Display Preservation**: Observe that "from Group 1" text displays correctly on unfixed code, then verify it continues after fix
3. **Timer Preservation**: Observe that 3-second timer triggers navigation on unfixed code, then verify it continues after fix
4. **Navigation Logic Preservation**: Observe that authentication-based routing works on unfixed code, then verify it continues after fix
5. **Container Dimensions Preservation**: Observe that circular container is 150x150 on unfixed code, then verify it continues after fix

### Unit Tests

- Test that FlutterLogo widget is present in the widget tree after fix
- Test that FlutterLogo size parameter is set to 150
- Test that Image.asset widget is NOT present after fix
- Test that ClipOval and SizedBox structure remains unchanged
- Test that background color remains Colors.blue
- Test that "from Group 1" text is displayed correctly

### Property-Based Tests

- Generate random app launch scenarios and verify Flutter logo is always displayed
- Generate random authentication states and verify navigation logic continues to work correctly
- Test that all visual elements (background, text, container) remain consistent across many renders

### Integration Tests

- Test full app launch flow with Flutter logo display
- Test that splash screen transitions to correct screen after 3 seconds
- Test that visual appearance matches expected design (blue background, circular logo, bottom text)
- Test across different device sizes to ensure logo scales appropriately within the circular container
