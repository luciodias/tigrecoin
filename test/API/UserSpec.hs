{-# LANGUAGE OverloadedStrings #-}

module API.UserSpec (spec) where

import Data.Aeson (object, (.=))
import Helper

import qualified Data.ByteString.Char8 as C
import qualified Data.Text as T
import qualified Data.UUID as UUID

spec = before_ cleanDb $ do
  describe "methodGet /api/users/{id}" $ do
    it "requires authentication" $ do
      get "/api/users/00000000-0000-0000-0000-000000000000"
        `shouldRespondWith` 401

    it "returns user for valid id" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      token <- loginUser ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      uid <- liftIO $ findUserIdByEmail "alice@test.com"
      request methodGet (C.pack $ "/api/users/" <> UUID.toString uid)
        [("Authorization", "Bearer " <> token)] ""
        `shouldRespondWith` 200

    it "returns 404 for non-existent id" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      token <- loginUser ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      request methodGet "/api/users/00000000-0000-0000-0000-000000000000"
        [("Authorization", "Bearer " <> token)] ""
        `shouldRespondWith` 404

  describe "methodPut /api/users/{id}" $ do
    it "updates user name and email" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      token <- loginUser ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      uid <- liftIO $ findUserIdByEmail "alice@test.com"
      let updateBody = encodeStrict $ object
            [ "name"  .= ("Alice Updated" :: T.Text)
            , "email" .= ("alice.updated@test.com" :: T.Text)
            ]
      request methodPut (C.pack $ "/api/users/" <> UUID.toString uid)
        [("Authorization", "Bearer " <> token), ("Content-Type", "application/json")]
        updateBody
        `shouldRespondWith` 200

  describe "methodDelete /api/users/{id}" $ do
    it "returns 403 for non-admin user" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      token <- loginUser ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      uid <- liftIO $ findUserIdByEmail "alice@test.com"
      request methodDelete (C.pack $ "/api/users/" <> UUID.toString uid)
        [("Authorization", "Bearer " <> token)] ""
        `shouldRespondWith` 403

    it "returns 204 for admin user" $ do
      registerUser ("Admin" :: T.Text) ("admin@test.com" :: T.Text) ("admin123" :: T.Text)
      liftIO $ promoteUserToAdmin "admin@test.com"
      token <- loginUser ("admin@test.com" :: T.Text) ("admin123" :: T.Text)
      registerUser ("DeleteMe" :: T.Text) ("delete@test.com" :: T.Text) ("secret123" :: T.Text)
      targetUid <- liftIO $ findUserIdByEmail "delete@test.com"
      request methodDelete (C.pack $ "/api/users/" <> UUID.toString targetUid)
        [("Authorization", "Bearer " <> token)] ""
        `shouldRespondWith` 204
