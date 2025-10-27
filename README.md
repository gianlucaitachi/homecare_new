# Homecare New

## Project Purpose
Homecare New is an end-to-end platform that helps home health agencies coordinate caregivers, schedule visits, and share care plans with families. The goal is to provide a lightweight reference implementation that demonstrates how the backend API and the Flutter mobile client interact to deliver core workflows such as onboarding a patient, assigning a caregiver, and capturing visit notes in the field.

## Backend Service
The repository now includes a lightweight Dart backend alongside the mobile client. It is intended for local development and health checks while the full production-ready Node.js/NestJS backend continues to live in a separate repository. You can run either service depending on your development needs.

### Dart Shelf Backend
The embedded backend is a minimal [Shelf](https://pub.dev/packages/shelf) server that exposes a health endpoint. It reads configuration from environment variables using [`dotenv`](https://pub.dev/packages/dotenv).

#### Prerequisites
- Dart SDK 3.0+

#### Environment Variables
Create a `.env` file at the project root (or in the directory where you invoke the server) with any variables you want to override. The only supported variable today is the port.

```
PORT=8080
```

If the `.env` file is omitted, the server defaults to port `8080`. You can also rely on the `PORT` variable from your shell environment.

#### Running the Shelf Backend Locally
1. Install dependencies with `dart pub get` (the command will resolve packages from `backend/pubspec.yaml`).
2. Start the server:
   ```bash
   dart run backend/bin/server.dart
   ```
3. Verify the health endpoint responds:
   ```bash
   curl http://localhost:8080/health
   # {"status":"ok"}
   ```

### Node.js/NestJS Backend
The full-featured backend service remains in its own repository and is implemented with Node.js and NestJS backed by PostgreSQL. The service exposes REST endpoints that power authentication, patient management, scheduling, and notification features consumed by the mobile client.

#### Prerequisites
- Node.js 18+
- npm (bundled with Node.js) or pnpm
- PostgreSQL 14+ running locally or accessible via a connection string
- Optional: Redis 6+ if you plan to enable session caching or rate limiting

#### Environment Variables
Create a `.env` file in the backend project that defines the following values:

```
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/homecare
PORT=3000
JWT_SECRET=change-me
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=secret
SMTP_FROM_ADDRESS=homecare@example.com
```

Adjust the connection strings to match your environment. The `DATABASE_URL` must point to the PostgreSQL instance that stores patient, caregiver, and visit data.

#### Running the Node Backend Locally
1. Clone the backend repository alongside this project (for example, into `../homecare_backend`).
2. Navigate to the backend directory: `cd ../homecare_backend`.
3. Copy the sample environment file if provided: `cp .env.example .env` and update the variables listed above.
4. Install dependencies: `npm install` (or `pnpm install`).
5. Run database migrations: `npm run migrate` (adjust to your project's migration script, e.g. `npm run prisma:migrate` if you use Prisma).
6. Start the development server with live reload: `npm run start:dev`.
7. Verify that the API is responding at `http://localhost:3000/health` (or your configured health endpoint).

## Flutter Mobile App
The mobile client is a Flutter application that caregivers use in the field to view schedules, receive push notifications, record visit outcomes, and synchronize data with the backend service when connectivity is available. The Flutter code lives in the `mobile_app` project directory.

### Prerequisites
- Flutter SDK 3.19+
- Dart 3.3+
- Android Studio or VS Code with Flutter/Dart extensions
- Xcode 15+ for iOS builds (macOS only)
- An Android emulator or iOS simulator/device

### Configuration
Create a `.env` (or use Dart define flags) in the Flutter project to point to your backend API. The most common configuration is the base API URL used for HTTP requests.

```
API_BASE_URL=http://localhost:3000
SENTRY_DSN=
GOOGLE_MAPS_API_KEY=
```

You can either load these values with a package such as `flutter_dotenv` or pass them at runtime:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=SENTRY_DSN= --dart-define=GOOGLE_MAPS_API_KEY=
```

### Running the Flutter App Locally
1. Ensure the backend server is running so the mobile client can authenticate.
2. Navigate to the Flutter project: `cd mobile_app`.
3. Fetch dependencies: `flutter pub get`.
4. Format and analyze (optional but recommended):
   - `flutter format lib`
   - `flutter analyze`
5. Run integration tests if available: `flutter test`.
6. Launch the app on an emulator or device: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`.
7. For iOS, open `ios/Runner.xcworkspace` in Xcode and run on a simulator or device after running `flutter pub get`.

## Coordinating Backend and Mobile Development
- Start PostgreSQL and (optionally) Redis before running the backend.
- Export the same environment variables for both backend and Flutter to keep URLs and feature toggles aligned.
- When testing on Android emulators, use `http://10.0.2.2:3000` to reach the backend running on your development machine. For iOS simulators, use `http://127.0.0.1:3000`.
- Keep your backend API documentation (e.g., Swagger/OpenAPI) up to date so the Flutter team can implement new features quickly.

## Additional Tips
- Use tools like `npm run lint` (backend) and `flutter analyze` (mobile) as part of your CI pipeline.
- Consider Docker Compose to spin up PostgreSQL, Redis, and the backend API together, then point the Flutter client at `http://localhost:3000`.
- Document any feature flags or optional modules in both backend and mobile READMEs to help new contributors get started quickly.
