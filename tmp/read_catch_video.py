import sys,subprocess
sys.path.insert(0,'D:/Pixelmania/tmp-video-tools')
import imageio_ffmpeg
exe=imageio_ffmpeg.get_ffmpeg_exe()
subprocess.run([exe,'-y','-i','C:/Medal/Clips/Screen Recording/MedalTVScreenRecording20261007151631037.mp4','-vf','fps=2,scale=480:-1,tile=5x8','-frames:v','1','D:/Pixelmania/catch-recording-sheet.jpg'],capture_output=True)
