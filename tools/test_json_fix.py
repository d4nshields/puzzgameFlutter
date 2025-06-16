#!/usr/bin/env python3
"""
Quick test for the JSON serialization fix
"""

import sys
import json
import numpy as np
from pathlib import Path

# Add the tools directory to path
sys.path.insert(0, str(Path(__file__).parent))
from optimize_puzzle_assets import convert_to_serializable, BoundingBox

def test_json_serialization():
    """Test that numpy types can be serialized."""
    
    # Test numpy types
    test_data = {
        "int64_value": np.int64(42),
        "int32_value": np.int32(24),
        "float64_value": np.float64(3.14),
        "array_value": np.array([1, 2, 3]),
        "regular_int": 10,
        "regular_float": 2.5,
        "string": "test"
    }
    
    # Test BoundingBox with numpy values
    bounds = BoundingBox(
        left=np.int64(10), 
        top=np.int64(20), 
        right=np.int64(30), 
        bottom=np.int64(40)
    )
    
    test_data["bounds"] = bounds.to_dict()
    
    try:
        # Try to serialize with our custom encoder
        json_str = json.dumps(test_data, default=convert_to_serializable, indent=2)
        print("✅ JSON serialization successful!")
        print("Sample output:")
        print(json_str[:200] + "..." if len(json_str) > 200 else json_str)
        
        # Test deserialization
        parsed = json.loads(json_str)
        print("✅ JSON deserialization successful!")
        
        return True
        
    except Exception as e:
        print(f"❌ JSON serialization failed: {e}")
        return False

if __name__ == '__main__':
    success = test_json_serialization()
    sys.exit(0 if success else 1)
