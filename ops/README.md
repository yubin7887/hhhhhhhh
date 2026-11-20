# 배포 활성화

GitHub Actions의 `Build and test`는 Java 21과 임시 MySQL로 테스트한다. main push가 성공하면 실행 JAR를 7일간 보관한다. EC2 타이머는 현재 main SHA의 성공한 push 실행에서만 JAR를 가져온다. SSH 인바운드 및 AWS 서비스 변경은 필요 없다.

1. 허용된 SSH 위치에서 EC2에 연결한다. EC2에서 `gh`, `curl`, `flock` 및 GitHub로의 HTTPS 송신이 가능한지 확인한다.
2. GitHub Actions 아티팩트 다운로드용으로 이 저장소에만 **Actions: Read-only** 권한을 준 fine-grained PAT를 발급한다. root 소유, 권한 0600의 `/etc/hackathon-deploy.env`에 `GH_TOKEN=...` 형식으로 저장한다. 토큰을 저장소, 명령 인자 또는 로그에 넣지 않는다.
3. EC2의 `ubuntu`가 기존 /home/ubuntu/app.jar를 읽고 교체할 수 있는지, `sudo -n -l /usr/bin/systemctl restart hackathon`이 성공하는지 확인한다. 필요 시 관리자에게 해당 명령만 허용하도록 요청한다. 운영 서비스의 DB 환경 변수와 실행 설정을 유지한다.
4. 검토한 main의 ops 디렉터리에서 다음을 실행한다.

```sh
sudo install -D -m 0755 ops/deploy.sh /usr/local/libexec/hackathon-deploy
sudo install -m 0644 ops/hackathon-deploy.service ops/hackathon-deploy.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now hackathon-deploy.timer
sudo systemctl start hackathon-deploy.service
sudo journalctl -u hackathon-deploy.service -n 30 --no-pager
```

Actions의 성공 SHA와 서버 로그의 `Deployed <SHA> ... verified API HTTP 200`를 대조한다. 기존 Nginx URL에서도 GET /api/hello가 200인지 확인한다. 기본 확인 주소는 http://127.0.0.1:8080/api/hello이며 서버에서 다르면 /etc/hackathon-deploy.env에 HEALTH_URL을 설정한다.

상태 확인에 실패하면 이전 JAR로 롤백하고 동일한 실패 실행은 재설치하지 않는다. GitHub Actions에서 다시 실행해도 run ID는 같으므로 문제 해결 후 해당 실행을 재배포하려면 EC2에서 `~/.local/state/hackathon-deploy/failed`를 지우고 서비스를 다시 시작한다. JAR 롤백은 DB 스키마 변경까지 되돌리지 않는다.
