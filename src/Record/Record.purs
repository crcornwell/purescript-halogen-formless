module Formless.Record where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype, unwrap, wrap)
import Data.Symbol (class IsSymbol, SProxy(..))
import Formless.Spec (FormSpec(..), InputField(..))
import Prim.Row as Row
import Prim.RowList as RL
import Record as Record
import Record.Builder (Builder)
import Record.Builder as Builder
import Type.Data.RowList (RLProxy(..))

-----
-- Examples

newtype Form f = Form
  { name :: f String String String }
derive instance newtypeForm :: Newtype (Form f) _

newtype MaybeOutput e i o = MaybeOutput (Maybe o)
derive instance newtypeMaybeOutput :: Newtype (MaybeOutput e i o) _

formSpec :: Form FormSpec
formSpec = Form
  { name: FormSpec { input: "", validator: pure } }

formInput :: Form InputField
formInput = Form
  { name: InputField { input: "", validator: pure, touched: false, result: Nothing } }

formMaybeOutput :: Form MaybeOutput
formMaybeOutput = Form
  { name: MaybeOutput (Just "") }

formSpecToInputFields' :: Form FormSpec -> Form InputField
formSpecToInputFields' = formSpecToInputFields

trim' :: Form InputField -> Form MaybeOutput
trim' = trim


-----
-- Functions

-- | A helper function that will run and apply all validation functions to current
-- | inputs to produce the same record, this time with results.
validateInputFields
  :: ∀ row xs form
   . RL.RowToList row xs
  => ValidateInputFields xs row () row
  => Newtype (form InputField) (Record row)
  => form InputField
  -> form InputField
validateInputFields r = wrap $ Builder.build builder {}
  where
    builder = validateInputFieldsBuilder (RLProxy :: RLProxy xs) (unwrap r)

-- | A helper function that will automatically transform a record of FormSpec(s) into
-- | a record of InputField(s).
formSpecToInputFields
  :: ∀ row xs row' form
   . RL.RowToList row xs
  => FormSpecToInputField xs row () row'
  => Newtype (form FormSpec) (Record row)
  => Newtype (form InputField) (Record row')
  => form FormSpec
  -> form InputField
formSpecToInputFields r = wrap $ Builder.build builder {}
  where
    builder = formSpecToInputFieldBuilder (RLProxy :: RLProxy xs) (unwrap r)

trim
  :: ∀ row xs row' form
   . RL.RowToList row xs
  => Trim xs row () row'
  => Newtype (form InputField) (Record row)
  => Newtype (form MaybeOutput) (Record row')
  => form InputField
  -> form MaybeOutput
trim r = wrap $ Builder.build builder {}
  where
    builder = trimBuilder (RLProxy :: RLProxy xs) (unwrap r)


-----
-- Classes (Internal)

-- | The class that provides the Builder implementation to efficiently apply validation
-- | to inputs and produce results
class ValidateInputFields (xs :: RL.RowList) (row :: # Type) (from :: # Type) (to :: # Type)
  | xs -> from to where
  validateInputFieldsBuilder :: RLProxy xs -> Record row -> Builder { | from } { | to }

instance validateInputFieldsNil :: ValidateInputFields RL.Nil row () () where
  validateInputFieldsBuilder _ _ = identity

instance validateInputFieldsCons
  :: ( IsSymbol name
     , Row.Cons name (InputField i e o) trash row
     , ValidateInputFields tail row from from'
     , Row.Lacks name from'
     , Row.Cons name (InputField i e o) from' to
     )
  => ValidateInputFields (RL.Cons name (InputField i e o) tail) row from to where
  validateInputFieldsBuilder _ r =
    first <<< rest
    where
      _name = SProxy :: SProxy name
      val = transform $ Record.get _name r
      rest = validateInputFieldsBuilder (RLProxy :: RLProxy tail) r
      first = Builder.insert _name val
      transform (InputField { input, touched, validator }) = InputField
        { input
        , touched
        , validator
        , result: Just $ validator input
        }

-- | The class that provides the Builder implementation to efficiently transform the record
-- | of FormSpec to record of InputField.
class FormSpecToInputField (xs :: RL.RowList) (row :: # Type) (from :: # Type) (to :: # Type)
  | xs -> from to where
  formSpecToInputFieldBuilder :: RLProxy xs -> Record row -> Builder { | from } { | to }

instance formSpecToInputFieldNil :: FormSpecToInputField RL.Nil row () () where
  formSpecToInputFieldBuilder _ _ = identity

instance formSpecToInputFieldCons
  :: ( IsSymbol name
     , Row.Cons name (FormSpec i e o) trash row
     , FormSpecToInputField tail row from from'
     , Row.Lacks name from'
     , Row.Cons name (InputField i e o) from' to
     )
  => FormSpecToInputField (RL.Cons name (FormSpec i e o) tail) row from to where
  formSpecToInputFieldBuilder _ r =
    first <<< rest
    where
      _name = SProxy :: SProxy name
      val = transform $ Record.get _name r
      rest = formSpecToInputFieldBuilder (RLProxy :: RLProxy tail) r
      first = Builder.insert _name val
      transform (FormSpec { input, validator }) = InputField
        { input
        , touched: false
        , validator
        , result: Nothing
        }


-- | The class that provides the Builder implementation to efficiently transform the record
-- | of FormSpec to record of InputField.
class Trim (xs :: RL.RowList) (row :: # Type) (from :: # Type) (to :: # Type)
  | xs -> from to where
  trimBuilder :: RLProxy xs -> Record row -> Builder { | from } { | to }

instance trimNil :: Trim RL.Nil row () () where
  trimBuilder _ _ = identity

instance trimCons
  :: ( IsSymbol name
     , Row.Cons name (InputField i e o) trash row
     , Trim tail row from from'
     , Row.Lacks name from'
     , Row.Cons name (MaybeOutput i e o) from' to
     )
  => Trim (RL.Cons name (MaybeOutput i e o) tail) row from to where
  trimBuilder _ r =
    first <<< rest
    where
      _name = SProxy :: SProxy name
      val = transform $ Record.get _name r
      rest = trimBuilder (RLProxy :: RLProxy tail) r
      first = Builder.insert _name val
      transform (InputField { result }) = MaybeOutput
        case result of
          Just (Right v) -> Just v
          _ -> Nothing