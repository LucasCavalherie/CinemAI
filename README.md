# FilmFinder

FilmFinder is an iOS app that helps users discover movies and TV shows based on their preferences. It uses AI-powered recommendations to suggest content that matches what users are looking for, whether they describe it in their own words or select from predefined categories.

![FilmFinder Logo](FilmFinder/Assets.xcassets/FilmFinder_logo.imageset/Contents.json)

## Features

### Personalized Recommendations
- Get movie and TV show recommendations tailored to your preferences
- Search using natural language descriptions
- Select from categories like genre, theme, and mood

### Content Discovery
- Browse recommended movies and TV shows with ratings and details
- View comprehensive information including plot summaries, release dates, and ratings
- Swipe through recommendations with an intuitive card interface

### Personal Library
- Mark movies and shows as favorites
- Track what you've watched
- Maintain a viewing history
- Easily access your content through the profile section

### User-Friendly Interface
- Modern, intuitive design
- Smooth onboarding experience
- Dark mode optimized for comfortable viewing

## Technology Stack

- **SwiftUI**: For building the user interface
- **Swift**: Core programming language
- **ChatGPT API**: Powers the recommendation engine
- **TMDB API**: Provides detailed movie and show information
- **UserDefaults**: Local storage for user preferences and library

## Architecture

The app follows a clean architecture approach with:

- **Models**: Structured data types for movies, series, and user interactions
- **Views**: UI components for different screens and features
- **Utilities**: Helper functions and extensions
- **API Services**: Communication with external data sources

### Key Components

- **ChatGptView**: Handles AI-powered recommendation generation
- **FilmView/SerieView**: Displays movie and TV show recommendations
- **DataManager**: Manages the user's content library and preferences
- **ProfileView**: Shows user statistics and saved content

## Setup Instructions

1. Clone the repository
2. Open the project in Xcode 14 or later
3. Create a `Secrets.swift` file in the project with your API keys:
   ```swift
   struct Secrets {
       static let CHATGPT_API_KEY = "your-openai-api-key"
       static let TMDB_API_KEY = "your-tmdb-api-key"
   }
