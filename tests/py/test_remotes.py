"""클라이언트가 기다리는 리모트는 서버가 시작할 때 미리 만들어야 한다.
(처음 쓸 때 만들면 클라이언트가 연결하기 전에 보낸 첫 이벤트가 사라짐)"""
import glob, os, re

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")


def read(pattern):
    return "\n".join(open(p, encoding="utf-8").read() for p in glob.glob(os.path.join(ROOT, pattern), recursive=True))


def start_bodies(src):
    # 각 서비스의 start() 본문 (다음 최상위 'function'/'return' 전까지)
    return "\n".join(m.group(1) for m in re.finditer(r"function \w+\.start\(\)(.*?)\n(?:function|return) ", src, re.S))


def test_client_remotes_created_at_server_start():
    client = read("src/client/**/*.luau")
    waited = set(re.findall(r'remotes:WaitForChild\("(\w+)"\)', client))
    server = read("src/server/**/*.luau")
    created = set(re.findall(r'Remotes\.get\("(\w+)"\)', start_bodies(server)))
    # 모듈 맨 위(들여쓰기 없음)에서 만드는 것도 시작할 때 만드는 것
    created |= set(re.findall(r'^local \w+ = Remotes\.get\("(\w+)"\)', server, re.M))
    missing = sorted(waited - created - {"Notify", "Sfx"})
    assert not missing, f"서버 start()에서 미리 만들지 않는 리모트: {missing}"
