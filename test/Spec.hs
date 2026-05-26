module Main where

import Test.Hspec (hspec, describe)
import Test.Hspec.Wai (with)

import qualified Auth.JWTSpec
import qualified API.AuthSpec
import qualified API.WalletSpec
import qualified API.UserSpec
import qualified API.TransactionSpec

import Helper (createTestPool, runTestMigrations, destroyTestPool, mkTestApp, setTestPool)

main :: IO ()
main = do
  pool <- createTestPool
  runTestMigrations pool
  setTestPool pool
  let app = mkTestApp pool
  hspec $ do
    describe "Auth.JWT" Auth.JWTSpec.spec
    with (return app) $ do
      describe "API.Auth" API.AuthSpec.spec
      describe "API.Wallet" API.WalletSpec.spec
      describe "API.User" API.UserSpec.spec
      describe "API.Transaction" API.TransactionSpec.spec
  destroyTestPool pool
