# 가상 터미널에서 실물 Step-Login 을 띄우고, 대기에 들어가면 Ctrl+C(\x03)를 넣는다. 사용: python3 q6lnc844-ctrlc.py <drive.ps1> <bootstrap.ps1> <sb>
import os, pty, sys, time, select, signal
drive, src, sb = sys.argv[1:4]
log = os.path.join(sb, 'home', 'install-jarvis', 'bootstrap.log')
pid, fd = pty.fork()
if pid == 0:
    os.execvp('pwsh', ['pwsh', '-NoProfile', '-File', drive, '-Src', src, '-Sb', sb])
out = b''
def pump(t):
    global out
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try: out += os.read(fd, 65536)
            except OSError: return
deadline = time.time() + 60
while time.time() < deadline:
    pump(0.3)
    try:
        if 'login stage: wait' in open(log, encoding='utf-8', errors='replace').read(): break
    except FileNotFoundError: pass
else:
    print('NO_WAIT_STAGE'); os.kill(pid, signal.SIGKILL); sys.exit(3)
pump(1.0)
os.write(fd, b'\x03')
end = time.time() + 60
st = None
while time.time() < end:
    pump(0.3)
    w, st = os.waitpid(pid, os.WNOHANG)
    if w: break
else:
    os.kill(pid, signal.SIGKILL); print('TIMEOUT'); sys.exit(4)
open(os.path.join(sb, 'screen.txt'), 'wb').write(out)
print('EXITED', st)
