import sys,subprocess
sys.path.insert(0,'D:/Pixelmania/tmp-video-tools')
import imageio_ffmpeg
r=subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-y','-ss','15','-i','C:/Medal/Clips/Screen Recording/MedalTVScreenRecording20261007151631037.mp4','-vf','fps=12,crop=iw*0.5:ih*0.65:iw*0.25:ih*0.3,scale=400:-1,tile=6x5','-frames:v','1','D:/Pixelmania/catch-detail-sheet.jpg'],capture_output=True)
