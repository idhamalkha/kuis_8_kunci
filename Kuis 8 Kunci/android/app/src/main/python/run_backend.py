#!/usr/bin/env python3
"""
Chaquopy Backend Wrapper
Runs FastAPI server dengan optimisasi untuk Android
"""

import os
import sys
import asyncio
import signal
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent))

def run_server():
    """Run the FastAPI server"""
    import uvicorn
    from app.main import app
    
    # Use 0.0.0.0 untuk accessible dari semua interfaces
    # Port 8000 atau 5000 untuk avoid conflicts
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info",
        access_log=True,
        reload=False,  # Disable reload untuk production
    )

if __name__ == "__main__":
    try:
        run_server()
    except KeyboardInterrupt:
        print("\nServer stopped")
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
