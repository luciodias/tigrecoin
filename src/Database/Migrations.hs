{-# LANGUAGE OverloadedStrings #-}

module Database.Migrations where

import Control.Exception (bracket)
import Data.List (sort)
import Database.PostgreSQL.Simple (Connection, execute_, query_, execute, Only(..), fromOnly)
import System.Directory (listDirectory)

import qualified Data.Text as T
import qualified Data.Text.IO as T

runMigrations :: Connection -> FilePath -> IO ()
runMigrations conn dir = do
  createMigrationsTable conn
  executed <- getExecutedMigrations conn
  files <- sort . filter (".sql" `T.isSuffixOf`) . fmap T.pack <$> listDirectory dir
  let pending = filter (`notElem` executed) files
  mapM_ (applyMigration conn dir) pending

createMigrationsTable :: Connection -> IO ()
createMigrationsTable conn =
  execute_ conn
    "CREATE TABLE IF NOT EXISTS _migrations ( \
    \  name TEXT PRIMARY KEY, \
    \  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW() \
    \)"

getExecutedMigrations :: Connection -> IO [Text]
getExecutedMigrations conn = do
  rows <- query_ conn "SELECT name FROM _migrations ORDER BY name" :: IO [Only Text]
  pure $ map fromOnly rows

applyMigration :: Connection -> FilePath -> Text -> IO ()
applyMigration conn dir file = do
  content <- T.readFile (T.unpack dir <> "/" <> T.unpack file)
  bracket (begin conn) (const $ commit conn) $ \_ -> do
    execute_ conn content
    execute conn "INSERT INTO _migrations (name) VALUES (?)" (Only file)
  putStrLn $ "Applied migration: " <> T.unpack file
  where
    begin   = flip execute_ "BEGIN"
    commit  = flip execute_ "COMMIT"
