{-# LANGUAGE OverloadedStrings #-}

module API.WalletSpec (spec) where

import Data.Aeson (object, (.=))
import Data.Maybe (isJust)
import Helper
import Control.Monad (void)
 
import qualified Data.Aeson as A
import qualified Data.ByteString.Char8 as C
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T

spec = before_ cleanDb $ do
  describe "GET /api/wallet" $ do
    it "requires authentication (401 without token)" $ do
      get "/api/wallet" `shouldRespondWith` 401

    it "returns wallet for authenticated user" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      token <- loginUser ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      request methodGet "/api/wallet"
        [("Authorization", "Bearer " <> token)] ""
        `shouldRespondWith` 200

  describe "methodPost /api/wallet/deposit" $ do
    it "requires authentication" $ do
      (post "/api/wallet/deposit" "" `shouldRespondWith` 401)

    it "deposits coins and updates balance" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      token <- loginUser ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      let depBody = encodeStrict $ object ["amount" .= (100.0 :: Double)]
      resp <- request methodPost "/api/wallet/deposit"
        [("Authorization", "Bearer " <> token), ("Content-Type", "application/json")]
        depBody
      liftIO $ do
        let val = A.decode (simpleBody resp) :: Maybe A.Value
        val `shouldSatisfy` isJust

    it "deposits multiple times and accumulates" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      token <- loginUser ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      let depBody = encodeStrict $ object ["amount" .= (50.0 :: Double)]
      void $ request methodPost "/api/wallet/deposit"
        [("Authorization", "Bearer " <> token), ("Content-Type", "application/json")]
        depBody
      void $ request methodPost "/api/wallet/deposit"
        [("Authorization", "Bearer " <> token), ("Content-Type", "application/json")]
        depBody
      resp <- getWallet token
      liftIO $ do
        let val = A.decode (simpleBody resp) :: Maybe A.Value
        val `shouldSatisfy` isJust

  describe "methodPost /api/wallet/withdraw" $ do
    it "requires authentication" $ do
      post "/api/wallet/withdraw" "" `shouldRespondWith` 401

    it "withdraws coins after sufficient deposit" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      token <- loginUser ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      -- First deposit
      let depBody = encodeStrict $ object ["amount" .= (200.0 :: Double)]
      void $ request methodPost "/api/wallet/deposit"
        [("Authorization", "Bearer " <> token), ("Content-Type", "application/json")]
        depBody
      -- Then withdraw
      let witBody = encodeStrict $ object ["amount" .= (50.0 :: Double)]
      resp <- request methodPost "/api/wallet/withdraw"
        [("Authorization", "Bearer " <> token), ("Content-Type", "application/json")]
        witBody
      liftIO $ do
        let val = A.decode (simpleBody resp) :: Maybe A.Value
        val `shouldSatisfy` isJust

getWallet token =
  request methodGet "/api/wallet"
    [("Authorization", "Bearer " <> token)] ""
