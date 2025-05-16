import { useState } from "react";

import "./styles.css";
import { createHeadlessForm } from "@remoteoss/json-schema-form";
import { formValuesToJsonValues, getDefaultValuesFromFields } from "./utils";
import {
  Box,
  Stack,
  LabelRadio,
  RadioOptions,
  Fieldset,
  InputText,
  Hint,
  ErrorMessage,
  Label
} from "./App.styled";

import ORDS from './ORDS';

// http://localhost/ords/apidays/schema_repository/products
const jsonSchemaDemo = await ORDS.getSchema();

//console.log(jsonSchemaDemo);

const fieldsMap = {
  text: FieldText,
  number: FieldNumber,
  radio: FieldRadio,
  error: FieldUnknown
};

const initialValuesFromAPI = {
    NAME: 'Mixing robot',
    PRICE: 99.99,
    QUANTITY: 10
}

export default function WithReact() {
  const { fields, handleValidation } = createHeadlessForm(jsonSchemaDemo, {
    strictInputType: false, // so you don't need to pass presentation.inputType,
    initialValues: initialValuesFromAPI,
  });
  async function handleOnSubmit(jsonValues, { formValues }) {
      alert(
        `Submitted with succes! ${JSON.stringify(
          { jsonValues },
          null,
          3
        )}`
      );
      console.log("Submitted!", { jsonValues });

      // insert form data as a JSON document into a JSON Relational Duality view
      await ORDS.insertNewProduct( jsonValues );
    }

  return (
    <article>
      <h1>Oracle Database 23ai JSON Schema<br/> with json-schema-form and React</h1>
      <p>This demo uses React without any other Form library. The JSON Schema is retrieved from the database used as a <b>central JSON Schema repository</b>.</p>
      <br />

      <SmartForm
        onSubmit={handleOnSubmit}
        // From JSF
        fields={fields}
        initialValues={initialValuesFromAPI}
        handleValidation={handleValidation}
      />
    </article>
  );
}

// ===============================
// ====== UI COMPONENTS ==========
// ===============================

function SmartForm({ name, fields, initialValues, handleValidation, onSubmit }) {
  const [values, setValues] = useState(() =>
    getDefaultValuesFromFields(fields, initialValues)
  );
  const [errors, setErrors] = useState({});
  const [submited, setSubmited] = useState(false);

  function handleInternalValidation(valuesToValidate) {
    const valuesForJson = formValuesToJsonValues(fields, valuesToValidate);
    const { formErrors } = handleValidation(valuesForJson);

    setErrors(formErrors || {});

    return {
      errors: formErrors,
      jsonValues: valuesForJson
    };
  }

  function handleFieldChange(fieldName, value) {
    const newValues = {
      ...values,
      [fieldName]: value
    };
    setValues(newValues);

    handleInternalValidation(newValues);
  }

  function handleSubmit(e) {
    e.preventDefault();
    setSubmited(true);

    const validation = handleInternalValidation(values);

    if (validation.errors) {
      return null;
    }

    return onSubmit(validation.jsonValues, { formValues: values });
  }

  return (
    <form name={name} onSubmit={handleSubmit} noValidate>
      <Stack gap="24px">
        {fields?.map((field) => {
          const { name: fieldName, inputType } = field;
          const FieldComponent = fieldsMap[inputType] || fieldsMap.error;

          return (
            <FieldComponent
              key={fieldName}
              value={values?.[fieldName]}
              error={errors[fieldName]}
              submited={submited}
              onChange={handleFieldChange}
              {...field}
            />
          );
        })}

        <button type="submit">Add Product</button>
      </Stack>
    </form>
  );
}

function FieldText({
  type,
  name,
  label,
  description,
  value,
  isVisible,
  error,
  submited,
  onChange,
  required,
  ...props
}) {
  const [touched, setTouched] = useState(false);

  if (!isVisible) return null;

  function handleChange(e) {
    if (!touched) setTouched(true);
    onChange(name, e.target.value);
  }

  return (
    <Box>
      <Label htmlFor={name}>{label}</Label>
      {description && <Hint id={`${name}-description`}>{description}</Hint>}
      <InputText
        id={name}
        type="text"
        defaultValue={value}
        onChange={handleChange}
        aria-invalid={!!error}
        aria-describedby={`${name}-error ${name}-description`}
        aria-required={required}
        {...props}
      />
      {(touched || submited) && error && (
        <ErrorMessage id={`${name}-error`}>{error}</ErrorMessage>
      )}
    </Box>
  );
}

function FieldNumber(props) {
  return (
    <FieldText
      inputMode="decimal"
      // accepts numbers and dots (eg 10, 15.50)
      pattern="^[0-9.]*$"
      {...props}
    />
  );
}

function FieldRadio({
  name,
  label,
  description,
  value,
  options,
  isVisible,
  error,
  submited,
  onChange
}) {
  const [touched, setTouched] = useState(false);

  if (!isVisible) return null;

  function handleChange(e) {
    if (!touched) setTouched(true);
    onChange(name, e.target.value);
  }

  const displayError = submited || touched ? error : null;

  return (
    <Fieldset key={name}>
      {/* A11Y errors: https://blog.tenon.io/accessible-validation-of-checkbox-and-radiobutton-groups/ */}
      <Label as="legend" aria-label={`${label} ${displayError}`}>
        {label}
      </Label>
      {description && <Hint>{description}</Hint>}
      <RadioOptions onChange={handleChange}>
        {options.map((opt) => (
          <LabelRadio key={opt.value}>
            <input
              type="radio"
              name={name}
              value={opt.value}
              defaultChecked={value === opt.value}
            />
            {opt.label}
          </LabelRadio>
        ))}
      </RadioOptions>
      {displayError && <ErrorMessage>{displayError}</ErrorMessage>}
    </Fieldset>
  );
}

function FieldUnknown({ type, name, error }) {
  return (
    <p style={{ border: "1px dashed gray", padding: "8px" }}>
      Field "{name}" unsupported: The type "{type}" has no UI component built
      yet.
      {error && <ErrorMessage id={`${name}-error`}>{error}</ErrorMessage>}
    </p>
  );
}
