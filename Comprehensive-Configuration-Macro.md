# Comprehensive Klipper Configuration and Macro Reference

This document serves as an authoritative reference for Klipper configuration options, macros, and resources. It consolidates information from official documentation, community resources, and GitHub repositories to provide a complete guide for Klipper users.

## Table of Contents

1. [Introduction to Klipper](#introduction-to-klipper)
2. [Configuration Options](#configuration-options)
   - [Printer Setup](#printer-setup)
   - [Stepper Motors](#stepper-motors)
   - [Extruder Configuration](#extruder-configuration)
   - [Bed Leveling and Mesh Calibration](#bed-leveling-and-mesh-calibration)
   - [Advanced Features](#advanced-features)
3. [Macros](#macros)
   - [Basic Macros](#basic-macros)
   - [Advanced Macros](#advanced-macros)
   - [Categorized Macro Index](#categorized-macro-index)
4. [Authoritative Resources](#authoritative-resources)
5. [Commands to Extract Printer-Specific Features](#commands-to-extract-printer-specific-features)
6. [Troubleshooting Common Issues](#troubleshooting-common-issues)
   - [Filament-Specific Adhesion Strategies](#filament-specific-adhesion-strategies)
   - [Advanced Klipper-Specific Diagnostics](#advanced-klipper-specific-diagnostics)
   - [Nozzle Wear and Maintenance](#nozzle-wear-and-maintenance)
   - [Gantry Squaring and Frame Rigidity](#gantry-squaring-and-frame-rigidity)
   - [Environmental Factors](#environmental-factors)
   - [Systematic Troubleshooting Guide](#systematic-troubleshooting-guide)

## Introduction to Klipper

Klipper is a 3D printer firmware that combines the computational power of a general-purpose computer (e.g., Raspberry Pi) with one or more microcontrollers to achieve precise and high-speed printing. It supports advanced features such as input shaping, pressure advance, and multi-MCU setups.

For new users, start with:

- [Klipper Documentation](https://www.klipper3d.org)
- [GitHub Repository](https://github.com/Klipper3d/klipper)
- [Klipper Installation Guide](https://www.klipper3d.org/Installation.html) - Step-by-step setup instructions
- [Configuration Checks](https://www.klipper3d.org/Config_checks.html) - Verify your setup

## Configuration Options

### Orca Slicer Configuration
Ensure MacOS privacy & security > local network has Orca Slicer enabled to allow it to communicate with Klipper.  Fluidd using moonraker API and is on port 7125.

### Printer Setup

Defines the printer's kinematics, motion limits, and basic parameters.

#### Cartesian Printer Example

```ini
[printer]
kinematics: cartesian
max_velocity: 300
max_accel: 3000
square_corner_velocity: 5.0
```

#### Common Printer Model Configurations

**Ender 3 S1 Example:**

```ini
[printer]
kinematics: cartesian
max_velocity: 300
max_accel: 3000
max_z_velocity: 5
max_z_accel: 100
square_corner_velocity: 5.0

[stepper_x]
step_pin: PC2
dir_pin: PB9
enable_pin: !PC3
microsteps: 16
rotation_distance: 40
endstop_pin: ^PA5
position_endstop: 0
position_max: 235
homing_speed: 50
```

### Stepper Motors

Defines the hardware configuration for stepper motors.

Example for X-axis stepper:

```ini
[stepper_x]
step_pin: PE0
dir_pin: PB0
enable_pin: !PC3
rotation_distance: 39.97 #Tested with 50mm XYZ Accuracy Test
microsteps: 16
endstop_pin: ^PA0
position_endstop: 0
position_max: 235

[stepper_y]
rotation_distance: 39.86 #Tested with 50mm XYZ Accuracy Test

[stepper_z]
rotation_distance: 8.06 #Tested with 50mm XYZ Accuracy Test
```

### Extruder Configuration

Defines the extruder's parameters, including heater and sensor settings.

Example:

```ini
[extruder]
step_pin: PD6
dir_pin: PD7
enable_pin: !PB9
gear_ratio: 42:12
rotation_distance: 25.46 #Confirmed with 0.01mm calipers and 100mm extrusion test
heater_pin: PB5
sensor_type: EPCOS 100K B57560G104F
sensor_pin: PA0

control: pid
pid_Kp: 22.2
pid_Ki: 1.08
pid_Kd: 114

min_temp: 0
max_temp: 250
pressure_advance: 0.2
```

### Bed Leveling and Mesh Calibration

#### Mesh Bed Leveling

```ini
[bed_mesh]
speed: 120             # Speed of probing moves.
horizontal_move_z: 5   # Z height during probing.
mesh_min: 35,6         # Minimum X,Y coordinate.
mesh_max: 240,198      # Maximum X,Y coordinate.
probe_count: 5,5       # Points to probe (X,Y).
fade_start: 1.0        # Z height to start fading out compensation.
fade_end: 10.0         # Z height to complete fade out.
```

#### Adaptive Bed Meshing (KAMP)

```ini
[gcode_macro ADAPTIVE_BED_MESH]
gcode:
    BED_MESH_CALIBRATE AREA_START={params.MINX},{params.MINY} AREA_END={params.MAXX},{params.MAXY}
    SAVE_CONFIG
```

### Advanced Features

1. **Input Shaping**:
   Reduces vibrations during high-speed printing.

   ```ini
   [input_shaper]
   shaper_freq_x = 40.0
   shaper_freq_y = 40.0
   ```

2. **Pressure Advance**:
   Improves extrusion consistency during acceleration/deceleration.

   ```ini
   pressure_advance = 0.2
   ```

3. **Resonance Compensation**:
   Uses an accelerometer to measure and reduce ringing.

   ```ini
   [resonance_tester]
   accel_chip = adxl345 
   ```

4. **Exclude Object**:
   Allows selective cancellation of objects during printing.

   ```ini
   [exclude_object]
   ```

   Usage example:

   ```gcode
   EXCLUDE_OBJECT NAME=my_test_cube
   ```

   > **Important:** When printing multiple objects and using the exclude_object feature, set your slicer's "Object Wall Loops" (or equivalent setting) to zero. This prevents perimeter overlaps between separate objects and ensures clean object separation, making it possible to properly exclude individual objects during printing.

5. **Board-Specific Configurations**:

   #### Orange Pi as Secondary MCU

   ```ini
   [mcu host]
   serial: /tmp/klipper_host_mcu
   
   [neopixel my_led]
   pin: host:gpio18
   chain_count: 16
   ```

6. **Virtual SDCard**:
   Allows Klipper to directly print gcode files.

   ```ini
   [virtual_sdcard]
   path: ~/gcode_files
   ```

7. **Firmware Retraction**:
   Enables firmware-based retraction control.

   ```ini
   [firmware_retraction]
   retract_length: 1.2
   retract_speed: 60 
   unretract_speed: 30
   unretract_extra_length: 0.0
   ```

   Usage:

   ```gcode
   G10 ; Retract
   G11 ; Unretract
   SET_RETRACTION RETRACT_LENGTH=1.5 ; Adjust settings on-the-fly
   ```

8. **Flow Calibration**:

   Flow rate calibration (extrusion multiplier) ensures accurate material extrusion. Results from flow calibration tests should be applied in both your slicer settings and can be adjusted on-the-fly in Klipper.

   ```ini
   [gcode_macro ADJUST_FLOW]
   gcode:
      SET_PRESSURE_ADVANCE ADVANCE={params.PA|default(0.02)}
      SET_EXTRUDER_FACTOR FACTOR={params.FLOW|default(1.0)}

   ```

9. **G-Code Arcs**:
   Enables arc commands for smoother curves.

   ```ini
   [gcode_arcs]
   resolution: 0.1
   ```

10. **Fan Control**:
   Advanced fan control settings.

   ```ini
   [fan]
   pin: PB5
   kick_start_time: 0.5
   off_below: 0.1
   cycle_time: 0.010
   
   [heater_fan hotend_fan]
   pin: PB6
   heater: extruder
   heater_temp: 50.0
   ```

## Macros

### Basic Macros

#### Homing All Axes

```ini
[gcode_macro HOME_ALL]
gcode:
    G28 ; Home all axes.
```

#### Preheat Bed and Extruder

```ini
[gcode_macro PREHEAT]
gcode:
    M190 S{params.BED_TEMP|default(60)}
    M104 S{params.EXTRUDER_TEMP|default(200)}
```

### Advanced Macros

#### Conditional Logic Example

```ini
[gcode_macro CONDITIONAL_EXAMPLE]
gcode:
{% if printer.extruder.temperature < 100 %}
    M117 Heating...
{% else %}
    M117 Ready!
{% endif %}
```

#### Filament Change Macro

```ini
[gcode_macro FILAMENT_CHANGE]
gcode:
    PAUSE 
    G91 ; Relative mode.
    G1 Z10 ; Raise nozzle.
    G90 ; Absolute mode.
    M117 Change filament now...
```

### Categorized Macro Index

1. **Motion Control**:
   - `HOME_ALL`: Homes all axes.
   - `MOVE_TO`: Moves to specific coordinates.

2. **Temperature Management**:
   - `PREHEAT`: Preheats bed and extruder.
   - `COOLDOWN`: Turns off heaters.

3. **Filament Handling**:
   - `FILAMENT_CHANGE`: Automates filament change.
   - `LOAD_FILAMENT`: Loads filament into the extruder.

4. **Custom Features**:
   - `SET_LED`: Controls LEDs on the printer.
   - `TOGGLE_POWER`: Toggles printer power supply.

## Authoritative Resources

1. **Official Documentation**:
   - [Klipper Configuration Reference](https://www.klipper3d.org/Config_Reference.html): Comprehensive list of configuration options.
   - [Command Templates](https://www.klipper3d.org/Command_Templates.html): Guide for creating advanced macros.

2. **GitHub Repositories**:
   - [Official Klipper Repository](https://github.com/Klipper3d/klipper): Source code and updates.
   - [Community Macros Repository](https://github.com/jschuh/klipper-macros): Ready-to-use macros.

3. **Community Resources**:
   - [Klipper Discord Server](https://discord.gg/klipper): Real-time support from experts.
   - [Reddit Community](https://www.reddit.com/r/klippers): Discussions and troubleshooting tips.

4. **System Management**:
   - [Backup and Restore Guide](https://github.com/th33xitus/kiauh) - KIAUH tool for managing Klipper instances
   - [Mainsail Backup Plugin](https://github.com/Staubgeborener/klipper-backup) - Automated backup solutions

## Commands to Extract Printer-Specific Features

To gather additional information about your printer's configuration and macros, use the following commands in Klipper:

1. **List Available Macros**:

   ```gcode
   GET_GCODE_MACROS 
   ```

2. **Dump Current Configuration**:

   ```gcode
   DUMP_CONFIG 
   ```

3. **Check Printer Status**:

   ```gcode
   M112 ; Emergency stop if needed.
   ```

4. **Test Input Shaping** (if accelerometer is installed):

   ```gcode
   SHAPER_CALIBRATE AXIS=X 
   ```

5. **Network Diagnostics**:

   ```gcode
   RESPOND MSG="Network check"
   ```

6. **Pressure Advance Tuning**:

   ```gcode
   TUNING_TOWER COMMAND=SET_PRESSURE_ADVANCE PARAMETER=ADVANCE START=0 FACTOR=.005
   ```

7. **Test Resonances with Graphs** (if accelerometer is installed):

   ```gcode
   TEST_RESONANCES AXIS=X OUTPUT=resonances_x_*.csv
   TEST_RESONANCES AXIS=Y OUTPUT=resonances_y_*.csv
   ```

These commands will help identify specific features or configurations unique to your setup.

## Troubleshooting Common Issues

This section addresses critical elements often overlooked when troubleshooting persistent issues like nozzle dragging and print detachment.

### Filament-Specific Adhesion Strategies

Different filaments require specific settings for optimal adhesion and print quality. Mismatched settings can cause both adhesion failures and nozzle dragging.

#### Filament-Specific Z-Offset and Bed Temperature Table

| Material | Z-Offset Adjustment | Bed Temp | First Layer Temp | Cooling | Additional Notes |
|----------|---------------------|----------|-----------------|---------|------------------|
| PLA      | Baseline            | 50-60°C  | 205-215°C       | 100%    | Use clean bed surface |
| PETG     | +0.05 to +0.1mm     | 70-80°C  | 230-240°C       | 30-50%  | Less squish prevents sticking to nozzle |
| TPU      | +0.05mm             | 40-50°C  | 220-230°C       | 0-20%   | Slower speeds (20-30mm/s) |
| ABS/ASA  | -0.02 to +0.05mm    | 100-110°C| 240-255°C       | 0-20%   | Enclosure recommended |
| Nylon    | +0.05mm             | 70-90°C  | 250-270°C       | 0%      | Dry filament crucial |

If first layer nozzle temperature is less than 205 degrees Celsius, the print may not adhere and get dragged across the bed.

```gcode
# Example macro for material-specific adjustments
[gcode_macro MATERIAL_ADJUST]
gcode:
    {% set material = params.MATERIAL|default("PLA")|upper %}
    {% if material == "PLA" %}
        SET_GCODE_OFFSET Z=0.0 MOVE=1
        M190 S60  # Bed temperature
        M104 S210 # Hotend temperature
        M106 S255 # Fan speed 100%
    {% elif material == "PETG" %}
        SET_GCODE_OFFSET Z=0.08 MOVE=1
        M190 S75
        M104 S235
        M106 S127 # Fan speed 50%
    {% elif material == "TPU" %}
        SET_GCODE_OFFSET Z=0.05 MOVE=1
        M190 S45
        M104 S225
        M106 S25  # Fan speed 10%
    {% endif %}
    M117 Adjusted settings for {material}
```

### Advanced Klipper-Specific Diagnostics

Klipper offers powerful diagnostic tools that can help identify mechanical issues often mistaken for simple Z-offset problems.

#### TMC Stepper Diagnostics

TMC stepper drivers can provide valuable diagnostic information:

```gcode
# Check stepper driver status
DUMP_TMC STEPPER=stepper_x
DUMP_TMC STEPPER=stepper_y
DUMP_TMC STEPPER=stepper_z

# Monitor for driver errors during print
[gcode_macro MONITOR_DRIVERS]
gcode:
    {% for stepper in ["stepper_x", "stepper_y", "stepper_z", "stepper_z1", "extruder"] %}
        {% if stepper in printer %}
            DUMP_TMC STEPPER={stepper}
        {% endif %}
    {% endfor %}
```

Look for `ot_warn` (overtemperature warning) or high `SG_RESULT` values which indicate motor strain.

#### Resonance Testing

Vibrations can cause layer shifts and print detachment:

```gcode
# Using ADXL345 accelerometer with Klippain Shake & Tune
AXIS_MAP_CALIBRATION # To align the sensor axes with printer axes.
AXIS_SHAPER_CALIBRATION # To measure both axis. AXIS=Y or X to do one axis at a time.
```

Check the generated CSV files for resonance peaks and adjust input shaper accordingly:

```ini
[input_shaper]
shaper_type_x = ei     # For lower vibrations (smoother prints)
shaper_freq_x = 75.8   # Higher frequency for EI shaper 
shaper_type_y = ei
shaper_freq_y = 52.8
damping_ratio_x: 0.098
damping_ratio_y: 0.055
```

#### Temperature Stability Testing

```gcode
# Hotend PID tuning
PID_CALIBRATE HEATER=extruder TARGET=210

# Bed PID tuning (if supported)
PID_CALIBRATE HEATER=heater_bed TARGET=60
```

Always run `SAVE_CONFIG` after successful PID tuning.
If using temperature tower, but sure to remove the macro from machine G-code in Orca Slicer to prevent it from running during normal prints.

### Nozzle Wear and Maintenance

A worn nozzle causes inconsistent extrusion leading to print defects often mistaken for Z-offset issues.

#### Nozzle Inspection Checklist

1. **Visual Inspection**:
   - Look for deformation, scratches, or buildup
   - Signs of wear include an asymmetrical hole or flattened tip

2. **Measurement**:
   - Use calipers to measure the nozzle hole (should match nominal size)
   - Standard 0.4mm nozzles should not exceed 0.45mm

3. **Cleaning Protocol**:

   ```gcode
   # Cold pull procedure
   M104 S170  # Heat to just below printing temperature
   # Wait 2 minutes, then manually pull filament to remove debris
   ```

4. **Replacement Schedule**:
   - Brass nozzles: Every 3-6 months of regular printing
   - Hardened steel: Every 9-12 months
   - Ruby/Tungsten: Check annually

5. **Post-Replacement Calibration**:

   ```gcode
   # After changing nozzle
   CALIBRATE_Z
   PROBE_ACCURACY
   ```

### Gantry Squaring and Frame Rigidity

A misaligned gantry causes inconsistent Z-height across the bed, leading to partial dragging and adhesion failures.

#### Gantry Squaring Procedure

1. **Manual Check**:
   - Use a machinist square at both ends of the X-axis gantry
   - Measure distance from X-axis extrusion to top frame at both ends

2. **Software Check**:

   ```gcode
   # Gantry leveling check (for dual Z motors)
   G28
   G0 X0 Y0 Z10
   TEST_Z_STEPPERS
   ```

3. **Belt Tension Verification**:
   - Use a belt tension meter or audio frequency test (free apps available). Y-axis is 82Hz.
   - X/Y belts should have similar tension (~140-160Hz for GT2 belts)

4. **Frame Rigidity Test**:
   - Print a tall, thin tower and check for wobble or layer shifts
   - For CoreXY, verify belt alignment and pulley tightness

### Environmental Factors

Environmental conditions often overlooked that significantly impact print quality and adhesion.

#### Airflow Management

1. **Draft Detection**:
   - Place tissue paper near printer during operation
   - Watch for movement indicating air currents

2. **Enclosure Recommendations**:

   ```ini
   # Environment monitoring configuration
   [temperature_sensor enclosure]
   sensor_type: DHT22
   pin: PA3  # Change to your MCU pin
   ```

3. **Air Currents Mitigation**:
   - For printers without enclosures, use draft shields in slicer
   - Consider DIY solutions (cardboard enclosures, etc.)

#### Filament Handling

1. **Humidity Effects**:
   - Even PLA can absorb moisture in 24-48 hours
   - Symptoms: popping sounds, inconsistent extrusion

2. **Drying Protocol**:
   - PLA: 45-50°C for 4-6 hours
   - PETG: 65°C for 4-6 hours
   - Nylon/PA: 75°C for 8-12 hours

3. **Storage Solutions**:
   - Vacuum-sealed bags with desiccant
   - Dry boxes with hygrometers

### Systematic Troubleshooting Guide

Follow this flowchart to systematically diagnose persistent print issues:

1. **Is the issue happening on all prints or specific geometries?**
   - All prints → Check Z-offset and bed leveling
   - Specific features → Check cooling and speed settings

2. **Does the nozzle drag throughout the print or just at certain heights?**
   - Throughout → Check Z-offset and bed mesh
   - At certain heights → Check Z-stepper binding or layer shift

3. **Do prints detach from corners first or center first?**
   - Corners → Check bed temperature and warping
   - Center → Check bed leveling and first layer speed

4. **Post-Leveling Z-Offset Validation**:
   - Print single-layer squares in all corners and center
   - Examine for consistent squish across all test squares
   - Inconsistency indicates gantry tilt, not just Z-offset issues

5. **Retraction and Z-Hop Balance**:

   ```ini
   # Balanced retraction settings
   [retraction]
   retract_length: 1.0
   retract_speed: 40
   unretract_speed: 30
   z_hop: 0.2  # Increase if nozzle drags on travel moves
   z_hop_speed: 5.0
   ```

6. **Safe `SAVE_CONFIG` Practice**:

   ```gcode
   # Before making significant changes
   SAVE_CONFIG BACKUP=True  # Creates timestamped backup
   
   # After confirming changes work correctly
   SAVE_CONFIG
   ```

7. **Network Connectivity Issues**:
   - If OctoPrint/Fluidd/Mainsail loses connection:
     - Check USB cable quality and connections
     - Verify MCU processor isn't overheating
     - Add `restart_method: command` to `[mcu]` section
     - Consider a powered USB hub
   -Set Host IP to: 192.168.1.95:7125 is the default port for Klipper, ensure it's not blocked by firewall or router settings.

8. **Pressure Advance Fine-Tuning**:

   ```ini
   # Multiple pressure advance values for different materials
   [gcode_macro START_PRINT]
   gcode:
       {% if params.FILAMENT|default("PLA")|upper == "PLA" %}
           SET_PRESSURE_ADVANCE ADVANCE=0.05
       {% elif params.FILAMENT|default("PLA")|upper == "PETG" %}
           SET_PRESSURE_ADVANCE ADVANCE=0.1
       {% endif %}
       # Rest of start sequence...
   ```

9. **SD Card and File Management**:
   - If the virtual SD card stops responding:
     - Check available space on host system
     - Consider using `SDCARD_RESET_FILE` command to clear problematic files

10. **Optimizing Performance**:
    - For 8-bit boards that struggle with complex models:
      - Increase `max_accel_to_decel` in `[printer]` section
      - Lower `square_corner_velocity` to reduce processing demands
      - Use Arc Welder plugin in slicer when possible

#### Summary Table: Common Issues & Solutions
| Issue | Why It Matters | Solution |
|-------|----------------|----------|
| Filament-specific tuning | PETG/PLA require different squish | Use material-specific Z-offsets (see table) |
| Klipper diagnostics | Stepper/resonance issues mimic dragging | Use `TMC_DEBUG`, `ACCELEROMETER_MEASURE` |  
| Nozzle wear | Worn nozzles cause erratic extrusion | Regular inspection and replacement (3-6 months) |
| Gantry squaring | Uneven Z-offset across the bed | Use machinist square and dual Z alignment |
| Environmental factors | Drafts/humidity warp prints | Add enclosure and implement filament drying |
| Backup practices | Inadvertent config overwriting | Always use `SAVE_CONFIG BACKUP=True` |

## Calibration Summary

### 1. Bed Leveling
```ini
[bed_mesh]
mesh_min: 41.8, 49
mesh_max: 170, 190
probe_count: 5,5

#*# [bed_mesh default]
#*# points = 0.102154, 0.027925, ... (auto-saved mesh data)
```

### 2. Pressure Advance
```ini
[extruder]
pressure_advance: 0.065
pressure_advance_smooth_time: 0.045
```

### 3. Input Shaping (ADXL345 Tuning)
```ini
[input_shaper]
shaper_type_x = ei
shaper_freq_x = 112.6
shaper_type_y = mzv
shaper_freq_y = 43.8
```

### 4. Retraction
```ini
[firmware_retraction]
retract_length: 1.5
retract_speed: 50
```

### 5. Flow Rate
Flow is adjusted in your slicer’s extrusion multiplier (e.g., Orca Slicer profile).
On May 16, 2025 the flow rate was estimated to be between 1.15 and 1.20 for PLA. Subsequent hollow cube calibrations show it at 0.92.

### 6. Z-Offset (CR Touch)
```ini
#*# [bltouch]
#*# z_offset = 2.939
```

### 7. Axis Twist Compensation
```ini
#*# [axis_twist_compensation]
#*# z_compensations = 0.041250, 0.043750, -0.085000
#*# compensation_start_x = 10.0
#*# compensation_end_x = 193.0
```

### 8. PID Tuning
```ini
[extruder]
pid_Kp: 23.561
pid_Ki: 1.208
pid_Kd: 114.859

[heater_bed]
pid_Kp: 71.867
pid_Ki: 1.536
pid_Kd: 840.843
```

### 9. Resonance Testing
```ini
[resonance_tester]
probe_points: 100,100,20
```

**Final Notes:**  
- Auto-saved `#*#` blocks should not be edited manually.  
- Use `PRESSURE_ADVANCE_TOWER`, `RETRACTION_TEST`, etc., for future calibrations.  
- Keep `max_accel: 5000` and `square_corner_velocity: 8.0` for stable, shaped motion.

## Conclusion

This document provides a comprehensive reference for configuring Klipper firmware and creating macros tailored to your printer's needs. For further assistance or advanced features, consult the official documentation or engage with the vibrant Klipper community on Discord or Reddit!

## References

1. SKR 1.3/1.4 Klipper Firmware | Voron Documentation [https://docs.vorondesign.com/build/software/skr13_klipper.html](https://docs.vorondesign.com/build/software/skr13_klipper.html)
2. klipper | Klipper is a 3d-printer firmware [https://mmone.github.io/klipper/Overview.html](https://mmone.github.io/klipper/Overview.html)
3. klipper/docs/Overview.md at master - GitHub [https://github.com/Klipper3d/klipper/blob/master/docs/Overview.md](https://github.com/Klipper3d/klipper/blob/master/docs/Overview.md)
4. Software Installation - Voron Documentation [https://docs.vorondesign.com/build/software/](https://docs.vorondesign.com/build/software/)
5. Welcome - Klipper documentation [https://www.klipper3d.org](https://www.klipper3d.org)
6. Klipper is a 3d-printer firmware - GitHub [https://github.com/Klipper3d/klipper](https://github.com/Klipper3d/klipper)
7. Setup guide to use klipper? : r/Ender3Pro - Reddit [https://www.reddit.com/r/Ender3Pro/comments/17zbgiq/setup_guide_to_use_klipper/](https://www.reddit.com/r/Ender3Pro/comments/17zbgiq/setup_guide_to_use_klipper/)
