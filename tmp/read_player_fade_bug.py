import sys,subprocess
sys.path.insert(0,'D:/Pixelmania/tmp-video-tools')
import imageio_ffmpeg
r=subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-y','-i','C:/Medal/Clips/PixelMania DEBUG/MedalTVPixelManiaDEBUG20261007154436219.mp4','-vf','fps=8,scale=480:-1,tile=6x8','-frames:v','1','D:/Pixelmania/player-fade-bug.jpg'],capture_output=True)
print(r.stderr.decode(errors='replace')[-650:])
