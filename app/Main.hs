{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Pool (withResource)
import Data.Time.Clock (secondsToNominalDiffTime)
import Network.Wai.Handler.Warp (run)
import System.Environment (lookupEnv)
import System.Exit (die)

import qualified Data.ByteString.Char8 as BS

import App (mkApp)
import Config (Env(..))
import Database.Connection (createConnectionPool)
import Database.Migrations (runMigrations)

main :: IO ()
main = do
  connString <- lookupEnv "DATABASE_URL" >>= \case
    Just s  -> pure s
    Nothing -> die "DATABASE_URL not set"

  jwtSecret <- lookupEnv "JWT_SECRET" >>= \case
    Just s  -> pure $ BS.pack s
    Nothing -> die "JWT_SECRET not set"

  port <- lookupEnv "PORT" >>= \case
    Just s  -> pure (read s :: Int)
    Nothing -> pure 8080

  pool <- createConnectionPool (BS.pack connString)

  putStrLn "Running database migrations..."
  withResource pool $ \conn -> runMigrations conn "migrations"
  putStrLn "Migrations complete."

  let env = Env
        { envPool      = pool
        , envJwtSecret = jwtSecret
        , envJwtExpiry = secondsToNominalDiffTime (24 * 3600)
        }

  putStrLn $ "Starting TigreCoin API on port " <> show port
  run port (mkApp env)
