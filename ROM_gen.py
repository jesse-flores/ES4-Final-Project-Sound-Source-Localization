"""
    While hand-calculations were possible, automating calculations was more 'efficient'
    A large language model agent was used in collaboration to develop this code aside from printing and comments.
"""
import numpy as np

FS = 46875.0 # Sample rate (Hz)
C = 343.0 # Speed of sound (m/s)
RADIUS = 0.25 # Distance to check points (far field)

# Microphone Coordinates (Meters)
# Physical positions of the three microphones
micA = np.array([0.01, 0.04]) # Reference microphone A
micB = np.array([0.10, 0.01]) # Microphone B
micC = np.array([0.15, 0.06]) # Microphone C

# Center of mass
centroid = (micA + micB + micC) / 3

micA = micA - centroid
micB = micB - centroid
micC = micC - centroid

# The 8 Compass Directions (Angles in degrees from positive X-axis)
# Standard mapping: 0 degrees = East, 90 degrees = North, 180 degrees = West, 270 degrees = South
angles_deg = [90, 45, 0, 315, 270, 225, 180, 135]
labels = ["N ", "NE", "E ", "SE", "S ", "SW", "W ", "NW"]

for i, deg in enumerate(angles_deg):
    rad = np.radians(deg)
    # Calculate point in the given direction at RADIUS distance
    p = np.array([np.cos(rad), np.sin(rad)]) * RADIUS

    # Calculating TDOA values
    # TDOA_AB = (distance to A - distance to B) / speed_of_sound * sample_rate
    dAB = (np.linalg.norm(p-micA) - np.linalg.norm(p-micB)) / C * FS
    dAC = (np.linalg.norm(p-micA) - np.linalg.norm(p-micC)) / C * FS

    # Round to nearest integer for fixed-point representation
    val_AB = int(round(dAB))
    val_AC = int(round(dAC))

    print(f"3'd{i}: begin exp_AB = {val_AB:3d}; exp_AC = {val_AC:3d}; end // {labels[i]}")