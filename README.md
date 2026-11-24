# 손글손글 · Flutter 앱

손글손글은 자음과 모음부터 문장까지 직접 써 보며 한글 손글씨를 연습하는 앱입니다. 글씨를 제출하면 글자 모양과 획순에 대한 피드백을 받고, 지난 연습 결과는 기록 화면에서 다시 볼 수 있습니다.

이 저장소에는 Flutter 앱이 있습니다. 평가와 학습 기록 저장은 [FastAPI 서버 저장소](https://github.com/AI-WritingCorrection/writingCollection_model)에서 다룹니다.

## 시연 및 다운로드

[시연 영상 1](https://youtu.be/hiKP2azsul4) · [시연 영상 2](https://youtu.be/4Eiu8ARfBwU)

[![Android APK 다운로드](https://img.shields.io/badge/Download-APK-green?style=flat)](https://drive.google.com/uc?export=download&id=13mRweaetV0183VmhngQ40QmPLdWyfani)

## 앱에서 할 수 있는 일

- 글자, 단어, 문장 단계별로 연습하고, 자유 연습에서 원하는 유형의 글씨를 씁니다.
- 제출한 글씨의 평가 결과와 고칠 부분을 확인합니다.
- 완료한 미션과 점수 변화를 기록 화면에서 확인합니다. 필기 화면은 태블릿 가로 모드를 기준으로 구성했습니다.

## 개발 환경에서 실행

Flutter 3.29.2(Dart 3.7.2)와 Android 에뮬레이터 또는 기기가 필요합니다. iOS에서 실행하려면 macOS와 Xcode가 필요합니다.

1. 서버와 같은 Firebase 프로젝트의 앱 설정 파일을 준비합니다. Android는 `android/app/google-services.json`, iOS는 `ios/Runner/GoogleService-Info.plist`에 둡니다. 소셜 로그인을 사용하려면 해당 로그인 제공자도 설정해야 합니다.
2. 저장소 루트에 `.env`를 만듭니다. 카카오 로그인을 사용할 경우 아래 두 키를 채웁니다.

   ```dotenv
   KAKAO_NATIVE_APP_KEY=
   KAKAO_JAVASCRIPT_APP_KEY=
   ```

3. [서버 실행 안내](https://github.com/AI-WritingCorrection/writingCollection_model#로컬에서-실행)를 따라 API를 띄우고, [`lib/api.dart`](lib/api.dart)의 `_baseUrl`을 기기에서 접근할 수 있는 주소로 설정합니다. 호스트에서 서버를 실행 중이라면 Android 에뮬레이터에서는 `http://10.0.2.2:8000/api`를 사용합니다. 실제 기기에서는 접근 가능한 서버 주소를 사용합니다.
4. 패키지를 설치하고 앱을 실행합니다.

   ```sh
   flutter pub get
   flutter devices
   flutter run
   ```

로그아웃 상태에서 로그인 화면이 열리는지 확인하는 위젯 테스트는 `flutter test test/app_test.dart`로 실행할 수 있습니다.

## 코드 구조

| 경로 | 역할 |
| --- | --- |
| [`lib/screen/`](lib/screen/) | 홈, 단계 학습, 자유 연습, 기록, 프로필 화면 |
| [`lib/widget/writing/`](lib/widget/writing/) | 필기 캔버스와 획 좌표, 글씨 이미지 처리 |
| [`lib/model/provider/`](lib/model/provider/) | Provider 기반 로그인, 언어, 학습 데이터 상태 |
| [`lib/design_system/`](lib/design_system/) | 앱 테마, 색상·글꼴·간격, 화면 크기 규칙 |
| [`lib/api.dart`](lib/api.dart) | 서버 API 호출 |

공통 스타일은 `app_theme.dart`와 `app_tokens.dart`에 있습니다. 화면 크기에 맞춰 조절하는 요소는 `AppLayout.scale`을 사용합니다. 세로 너비 390, 가로 높이 844 논리 픽셀을 기준으로 하며, 큰 태블릿에서도 기본 크기의 1배까지만 확대됩니다.

## 앱과 서버 구성

Flutter 앱은 필기 이미지와 획 좌표를 서버에 보내고, 돌아온 점수와 피드백을 표시합니다.

![손글손글 앱과 서버 구성도](https://github.com/user-attachments/assets/0ffa0c25-86fb-4e9a-9e06-64f2d18b928a)

## 만든 사람들

| 이름 | 역할 |
| --- | --- |
| 정영진 | 팀장, 프런트엔드 |
| 박세환 | 프런트엔드·백엔드 |
| 류효상 | 모델 개발·데이터 수집 및 정리 |
| 신주원 | 모델 개발·데이터 수집 및 정리 |
