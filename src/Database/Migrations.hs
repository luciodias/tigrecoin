{-# LANGUAGE OverloadedStrings #-}

module Database.Migrations where

import Control.Exception (bracket)
import Control.Monad (void)
import Data.List (sort)
import Data.Text (Text)
import Database.PostgreSQL.Simple (Connection, execute_, query_, execute, Only(..), fromOnly)
import Database.PostgreSQL.Simple.Types (Query(..))
import System.Directory (listDirectory)

import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.IO as TIO

runMigrations :: Connection -> FilePath -> IO ()
runMigrations conn dir = do
  createMigrationsTable conn
  executed <- getExecutedMigrations conn
  files <- sort . filter (".sql" `T.isSuffixOf`) . fmap T.pack <$> listDirectory dir
  let pending = filter (`notElem` executed) files
  mapM_ (applyMigration conn dir) pending

createMigrationsTable :: Connection -> IO ()
createMigrationsTable conn = void $
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
  content <- TIO.readFile (dir <> "/" <> T.unpack file)
  bracket (begin conn) (const $ void $ commit conn) $ \_ -> do
    void $ execute_ conn (Query (TE.encodeUtf8 content))
    void $ execute conn "INSERT INTO _migrations (name) VALUES (?)" (Only file)
  putStrLn $ "Applied migration: " <> T.unpack file
  where
    begin   = void . flip execute_ "BEGIN"
    commit  = void . flip execute_ "COMMIT"
