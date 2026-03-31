# Running iFux on iPhone 16 - Setup Guide

## 🚀 Quick Start: Run on Your iPhone 16

### Step 1: Connect Your iPhone
1. Connect your iPhone 16 to your Mac using a USB-C cable
2. Unlock your iPhone and tap **"Trust This Computer"** if prompted

### Step 2: Select Your Device in Xcode
1. At the top of Xcode, click the device selector (next to the Run button)
2. Select your **iPhone 16** from the list
3. Click the **Run button (▶️)** or press `Cmd + R`

### Step 3: Configure Signing (First Time Only)
1. In Xcode, select the **iFux project** in the navigator
2. Select the **iFux target**
3. Go to the **Signing & Capabilities** tab
4. Check ✅ **"Automatically manage signing"**
5. Under **Team**, select your Apple ID (Personal Team)

### Step 4: Trust Developer on iPhone (First Time Only)
After the app installs, you'll see "Untrusted Developer" when opening it:
1. On your iPhone, go to **Settings → General → VPN & Device Management**
2. Under "Developer App", tap your Apple ID
3. Tap **"Trust [Your Apple ID]"**
4. Confirm by tapping **"Trust"**

### Step 5: Grant Local Network Access
When you first run the app, iOS will ask for Local Network permission:
- Tap **"Allow"** to let the app find `fux.local` on your network

---

## ⚙️ Required Configuration: Info.plist

Your app needs permission to access the local network. Add these entries to your **Info.plist**:

### Using Xcode UI:
1. Select **iFux** target → **Info** tab
2. Hover over any row and click **+**
3. Add these keys:

| Key | Type | Value |
|-----|------|-------|
| `Privacy - Local Network Usage Description` | String | `iFux needs local network access to connect to your LED controller at fux.local` |
| `Bonjour services` | Array | (Add item) `_ws._tcp` |

### Or Edit Info.plist Directly:
Add this XML inside the `<dict>` tag:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>iFux needs local network access to connect to your LED controller at fux.local</string>
<key>NSBonjourServices</key>
<array>
    <string>_ws._tcp</string>
</array>
```

---

## 📱 Wireless Debugging (Optional)

After connecting once via cable, enable wireless deployment:

### Enable Wireless Connection:
1. Keep iPhone connected via cable
2. Go to **Window → Devices and Simulators** (or `Shift + Cmd + 2`)
3. Select your iPhone from the sidebar
4. Check ✅ **"Connect via network"**
5. Wait for the network icon to appear next to your device
6. Disconnect the cable - your iPhone stays connected!

### Requirements:
- Mac and iPhone on the same WiFi network
- iPhone must be connected via cable at least once
- Both devices must have WiFi and Bluetooth enabled

---

## 🌐 Network Setup for LED Control

### Same Network Requirement
Your iPhone must be on the **same WiFi network** as your Raspberry Pi for the app to work.

### Connection Methods:

**Option 1: Hostname (Recommended)**
- Default: `fux.local`
- Requires mDNS/Bonjour to be working on your network
- Most home routers support this

**Option 2: IP Address (Fallback)**
- Use IP directly: `192.168.1.21` (or your Pi's IP)
- Find your Pi's IP: `hostname -I` on the Raspberry Pi
- More reliable on some networks

### Test Connection:
1. Launch iFux on your iPhone
2. Navigate to **Effect Control**
3. Check the connection status bar at the top:
   - 🟢 **Green** = Connected successfully
   - 🔴 **Red** = Connection failed

If connection fails:
1. Tap the status bar to open connection settings
2. Enter your Raspberry Pi's IP address
3. Tap **"Connect"**

---

## 🐛 Troubleshooting

### "Untrusted Developer" Error
**Solution:** Settings → General → VPN & Device Management → Trust your Apple ID

### "Unable to Install" Error
**Solutions:**
1. Check that your Apple ID is signed in: Xcode → Settings → Accounts
2. Delete the app from iPhone if it's already installed
3. Clean build folder: Product → Clean Build Folder (`Shift + Cmd + K`)
4. Try again

### Code Signing Error
**Solutions:**
1. Make sure "Automatically manage signing" is checked
2. Select a team (your Personal Team)
3. Change the Bundle Identifier if needed (make it unique)

### Connection to fux.local Fails
**Solutions:**
1. Verify both devices are on the same WiFi network
2. Check that Local Network permission is granted
3. Try using IP address instead:
   - Tap the connection status bar
   - Enter your Pi's IP: `192.168.1.21`
   - Tap "Connect"
4. Verify Raspberry Pi backend is running:
   - SSH into your Pi
   - Check if WebSocket server is running on port 80
   - Test with: `curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" http://fux.local/`

### App Crashes on Launch
**Solutions:**
1. Check Xcode console for error messages
2. Verify all files compiled successfully
3. Clean build and rebuild: `Shift + Cmd + K`, then `Cmd + R`

### Local Network Permission Not Requested
**Solutions:**
1. Verify Info.plist has `NSLocalNetworkUsageDescription` key
2. Delete app from iPhone and reinstall
3. Reset privacy settings: Settings → General → Transfer or Reset iPhone → Reset → Reset Location & Privacy

---

## 📋 Pre-Flight Checklist

Before running on iPhone 16:

- [ ] iPhone connected via USB-C cable
- [ ] iPhone unlocked and trusted
- [ ] Apple ID added to Xcode (Xcode → Settings → Accounts)
- [ ] Signing configured (Automatically manage signing enabled)
- [ ] Info.plist has `NSLocalNetworkUsageDescription` key
- [ ] iPhone and Raspberry Pi on same WiFi network
- [ ] Raspberry Pi backend is running and accessible
- [ ] Backend WebSocket server running on port 80

---

## 🎯 First Run Steps

1. **Launch Xcode** with your iFux project
2. **Connect iPhone 16** via cable
3. **Select iPhone 16** as target device
4. **Click Run** (▶️) or press `Cmd + R`
5. **Wait for build** and installation
6. **Trust developer** on iPhone (if first time)
7. **Allow Local Network** permission when prompted
8. **Navigate to Effect Control** from the main menu
9. **Verify connection** (should show green status)
10. **Test modes** (Random and Queue)

---

## 💡 Tips

### Development Mode
- Keep Xcode open to see console logs
- Use breakpoints for debugging
- Watch console for WebSocket messages

### Battery Optimization
- The app maintains a WebSocket connection
- For longer use, keep iPhone plugged in or close the app when not in use

### Network Performance
- WiFi is much better than cellular (even if tethering)
- 5GHz WiFi networks typically have better performance
- Stay within good WiFi range for responsive control

---

## 🎊 You're Ready!

Once everything is set up, you can:
- Control LED effects from anywhere on your WiFi network
- Switch between Random and Queue modes
- Build custom effect queues
- Monitor connection status in real-time

Enjoy controlling your LED animations from your iPhone 16! 🌈✨
