# Trainy — тренировки собаки (SwiftUI MVP)

База для приложения: вход по email/паролю или через Google (Firebase Auth), профиль собаки с фото, каталог упражнений (15 упражнений уже включены), тренировочная сессия, журнал прогресса и графики статистики. Данные о собаке и тренировках хранятся локально через SwiftData, аккаунт пользователя — через Firebase Authentication.

## Структура

```
TrainyCatsDogs/
  TrainyCatsDogsApp.swift     — точка входа, настройка SwiftData и Firebase
  Info.plist                  — настройки приложения + URL-схема для входа через Google
  ContentView.swift           — корневой экран после входа (онбординг или TabView)
  Theme/
    Theme.swift                — цвета, градиент, стиль карточек
  Services/
    AuthService.swift          — обёртка над Firebase Auth (email/пароль + Google)
  Models/
    Dog.swift                  — профиль собаки (+ фото)
    Exercise.swift
    TrainingSession.swift
  Views/
    RootView.swift             — показывает LoginView или ContentView в зависимости от входа
    Auth/
      LoginView.swift          — вход и регистрация
    DogOnboardingView.swift    — создание профиля собаки при первом запуске
    ExerciseCatalogView.swift  — список упражнений с фильтром по категории
    ExerciseDetailView.swift   — описание, шаги, кнопка «Начать тренировку»
    TrainingSessionView.swift  — чек-лист + отметка результата
    ProgressJournalView.swift  — история тренировок, счётчик и стрик
    StatsView.swift            — графики статистики (Swift Charts)
    DogProfileView.swift       — фото и данные собаки, аккаунт, выход
  Resources/
    SeedExercises.swift        — 15 стартовых упражнений
  Assets.xcassets/             — иконка приложения
project.yml                    — спецификация для XcodeGen (включает пакеты Firebase и GoogleSignIn)
```

## Шаг 1 — заведи Firebase-проект (нужно один раз, ~10 минут)

Вход по email/паролю и через Google работает через Firebase Authentication — это бесплатный облачный сервис от Google. Без этого шага приложение не запустится (упадёт при старте), поэтому сделай его до первого запуска.

1. Открой [console.firebase.google.com](https://console.firebase.google.com) и войди под своим Google-аккаунтом.
2. **Add project** → назови проект, например `Trainy` → можно отключить Google Analytics (не обязателен) → **Create project**.
3. В боковом меню открой **Build → Authentication** → **Get started**.
4. На вкладке **Sign-in method** включи два провайдера:
   - **Email/Password** — просто включи переключатель и сохрани.
   - **Google** — включи, укажи email поддержки (свой), сохрани.
5. Вернись на главную страницу проекта и нажми иконку **iOS** («Add app»).
6. **Bundle ID**: укажи ровно `com.lisakochergina.trainycatsdogs` (важно — должно совпадать с тем, что в `project.yml`). Nickname и App Store ID — можно пропустить.
7. Нажми **Register app**, затем **скачай файл `GoogleService-Info.plist`** — он тебе понадобится дальше. Остальные шаги мастера («Add SDK», «Add code») можно пропустить — они уже сделаны в этом проекте.

## Шаг 2 — добавь файл конфигурации в проект

1. Найди скачанный `GoogleService-Info.plist` (обычно в папке Загрузки).
2. Перетащи его прямо в папку `TrainyCatsDogs` (туда же, где `ContentView.swift`) — рядом с исходниками, **не** в корень репозитория.
3. Открой этот файл (можно двойным кликом в Finder или через любой текстовый редактор) и найди строку `REVERSED_CLIENT_ID` — скопируй её значение (выглядит как `com.googleusercontent.apps.XXXXXXXXXX-yyyyyyyy...`).
4. Открой `TrainyCatsDogs/Info.plist` и замени строку `REPLACE_WITH_REVERSED_CLIENT_ID` на скопированное значение.

## Шаг 3 — установи XcodeGen (если ещё не установлен)

```
brew install xcodegen
```

## Шаг 4 — сгенерируй проект и открой в Xcode

```
cd ~/Trainy-Cats-Dogs
xcodegen generate
open TrainyCatsDogs.xcodeproj
```

При первом открытии Xcode сам скачает пакеты Firebase и GoogleSignIn через Swift Package Manager (нужен интернет, может занять пару минут — прогресс виден вверху окна).

## Шаг 5 — запусти

1. В строке рядом с именем схемы выбери **не** «Any iOS Device», а конкретный симулятор iPhone (iOS 17+).
2. Нажми ▶️ (или ⌘R).
3. На экране входа зарегистрируй аккаунт (email + пароль от 6 символов) или войди через Google.
4. Дальше — обычный цикл: создать профиль собаки → выбрать упражнение → провести тренировку → посмотреть прогресс и статистику.

## Что дальше

1. Проверь на реальном iPhone через прямой запуск (нужен Apple ID, добавленный в Xcode → Settings → Accounts). Если планируешь публиковать в App Store — Apple потребует добавить туда же и «Sign in with Apple», раз используется вход через Google.
2. Расширяй библиотеку упражнений в `Resources/SeedExercises.swift` или добавь экран создания собственных упражнений.
3. Модель `Exercise` уже содержит поля `isCustom` и `authorName` — задел под будущий шеринг упражнений между пользователями (фаза 2), синхронизацию тренировок между устройствами одного аккаунта тоже можно добавить на основе уже подключённого Firebase.
