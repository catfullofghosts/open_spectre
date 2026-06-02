import re
import matplotlib.pyplot as plt
import numpy as np

# Read the ROM file
with open('rom_view_sin.py', 'r') as f:
    content = f.read()

# Extract all binary strings using regex
binary_pattern = r'"([01]{12})"'
binary_strings = re.findall(binary_pattern, content)

# Convert binary strings to integers (unsigned 12-bit)
values = [int(b, 2) for b in binary_strings]

print(f"Total ROM entries: {len(values)}")
print(f"First value: {values[0]} (binary: {binary_strings[0]})")
print(f"Last value: {values[-1]} (binary: {binary_strings[-1]})")
print(f"Min value: {min(values)}")
print(f"Max value: {max(values)}")

# Calculate differences between consecutive values to detect discontinuities
differences = [abs(values[i+1] - values[i]) for i in range(len(values)-1)]
max_diff = max(differences)
max_diff_idx = differences.index(max_diff)

print(f"\nMaximum difference between consecutive values: {max_diff} at index {max_diff_idx}")

# Check for large jumps (potential discontinuities)
threshold = 100  # Adjust this threshold as needed
large_jumps = [(i, diff) for i, diff in enumerate(differences) if diff > threshold]
if large_jumps:
    print(f"\nFound {len(large_jumps)} large jumps (> {threshold}):")
    for idx, diff in large_jumps[:10]:  # Show first 10
        print(f"  Index {idx} to {idx+1}: difference = {diff}")
else:
    print(f"\nNo large jumps found (threshold: {threshold})")

# Create the plot
fig, axes = plt.subplots(2, 1, figsize=(12, 10))

# Plot 1: Full ROM values
axes[0].plot(values, 'b-', linewidth=1.5, label='ROM Values')
axes[0].set_xlabel('Index')
axes[0].set_ylabel('Value (12-bit unsigned)')
axes[0].set_title('VHDL Sine ROM - Full Plot')
axes[0].grid(True, alpha=0.3)
axes[0].legend()

# Plot 2: Differences between consecutive values
axes[1].plot(differences, 'r-', linewidth=1.5, label='Difference')
axes[1].axhline(y=threshold, color='orange', linestyle='--', label=f'Threshold ({threshold})')
axes[1].set_xlabel('Index')
axes[1].set_ylabel('Absolute Difference')
axes[1].set_title('Consecutive Value Differences (Discontinuity Detection)')
axes[1].grid(True, alpha=0.3)
axes[1].legend()

# Highlight large jumps
if large_jumps:
    for idx, diff in large_jumps:
        axes[1].plot(idx, diff, 'ro', markersize=8)

plt.tight_layout()
plt.savefig('rom_plot.png', dpi=150, bbox_inches='tight')
print(f"\nPlot saved as 'rom_plot.png'")
plt.show()

# Additional analysis: Check if it's a proper sine wave
# Calculate expected sine values for comparison
angles = np.linspace(0, 2*np.pi, len(values))
expected_sine = (np.sin(angles) + 1) / 2 * (2**12 - 1)  # Normalize to 0-4095

# Plot comparison
fig2, ax = plt.subplots(figsize=(12, 6))
ax.plot(values, 'b-', linewidth=1.5, label='ROM Values', alpha=0.7)
ax.plot(expected_sine, 'r--', linewidth=1.5, label='Expected Sine Wave', alpha=0.7)
ax.set_xlabel('Index')
ax.set_ylabel('Value')
ax.set_title('ROM Values vs Expected Sine Wave')
ax.grid(True, alpha=0.3)
ax.legend()
plt.tight_layout()
plt.savefig('rom_sine_comparison.png', dpi=150, bbox_inches='tight')
print(f"Comparison plot saved as 'rom_sine_comparison.png'")
plt.show()

