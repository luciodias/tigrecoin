{-# LANGUAGE OverloadedStrings #-}

module API.TransactionSpec (spec) where
 
import Data.Aeson (object, (.=))
import Data.Text (Text)
import Helper
import Control.Monad (void)
import Network.HTTP.Types (methodPost, methodGet, methodPut, methodDelete)

import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy as BL

spec = before_ cleanDb $ do
  describe "GET /api/transactions" $ do
    it "requires authentication" $ do
      request methodGet "/api/transactions" [] "" `shouldRespondWith` 401

    it "returns empty list when no transactions" $ do
      registerUser ("Alice" :: Text) ("alice@test.com" :: Text) ("secret123" :: Text)
      token <- loginUser ("alice@test.com" :: Text) ("secret123" :: Text)
      resp <- request methodGet "/api/transactions"
        [("Authorization", "Bearer " <> token)] ""
      liftIO $ do
        let val = A.decode (simpleBody resp) :: Maybe [A.Value]
        val `shouldBe` Just []

    it "returns transactions after deposit" $ do
      registerUser ("Alice" :: Text) ("alice@test.com" :: Text) ("secret123" :: Text)
      token <- loginUser ("alice@test.com" :: Text) ("secret123" :: Text)
      let depBody = encodeStrict $ object ["amount" .= (100.0 :: Double)]
      void $ request methodPost "/api/wallet/deposit"
        [("Authorization", "Bearer " <> token), ("Content-Type", "application/json")]
        depBody
      resp <- request methodGet "/api/transactions"
        [("Authorization", "Bearer " <> token)] ""
      liftIO $ do
        let val = A.decode (simpleBody resp) :: Maybe [A.Value]
        case val of
          Just (_:_) -> pure ()
          _          -> expectationFailure "Expected at least one transaction"

    it "returns both deposit and withdraw transactions" $ do
      registerUser ("Alice" :: Text) ("alice@test.com" :: Text) ("secret123" :: Text)
      token <- loginUser ("alice@test.com" :: Text) ("secret123" :: Text)
      let depBody = encodeStrict $ object ["amount" .= (200.0 :: Double)]
      void $ request methodPost "/api/wallet/deposit"
        [("Authorization", "Bearer " <> token), ("Content-Type", "application/json")]
        depBody
      let witBody = encodeStrict $ object ["amount" .= (50.0 :: Double)]
      void $ request methodPost "/api/wallet/withdraw"
        [("Authorization", "Bearer " <> token), ("Content-Type", "application/json")]
        witBody
      resp <- request methodGet "/api/transactions"
        [("Authorization", "Bearer " <> token)] ""
      liftIO $ do
        let val = A.decode (simpleBody resp) :: Maybe [A.Value]
        case val of
          Just txns -> length txns `shouldBe` 2
          Nothing   -> expectationFailure "Failed to decode transaction list"

  describe "GET /api/transactions/{id}" $ do
    it "requires authentication" $ do
      request methodGet "/api/transactions/00000000-0000-0000-0000-000000000000" [] "" `shouldRespondWith` 401

    it "returns 404 for non-existent id" $ do
      registerUser ("Alice" :: Text) ("alice@test.com" :: Text) ("secret123" :: Text)
      token <- loginUser ("alice@test.com" :: Text) ("secret123" :: Text)
      request methodGet "/api/transactions/00000000-0000-0000-0000-000000000000"
        [("Authorization", "Bearer " <> token)] ""
        `shouldRespondWith` 404
