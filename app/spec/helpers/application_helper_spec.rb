require "rails_helper"

RSpec.describe ApplicationHelper do
  describe "#agency_translation" do
    let(:current_agency) { Rails.application.config.client_agencies["sandbox"] }
    let(:available_translations) { <<~YAML }
        some_prefix:
          sandbox: some string
          default: default string
      YAML

    before do
      without_partial_double_verification do
        allow(helper).to receive(:current_agency).and_return(current_agency)
      end
    end

    around do |example|
      # Replace our actual I18n strings with the ones specified in the test
      # variable (available_translations) above.
      previous_backend = I18n.backend
      I18n.backend = I18n::Backend::Simple.new
      I18n.backend.store_translations(:en, YAML.load(available_translations))
      example.run
      I18n.backend = previous_backend
    end

    context "when the current_agency is specified" do
      it "uses the translation for the proper key" do
        expect(helper.agency_translation("some_prefix")).to eq("some string")
      end

      context "when there is not a translation for that client agency" do
        let(:current_agency) { Rails.application.config.client_agencies["applesauce"] }

        it "uses the translation for the default key" do
          expect(helper.agency_translation("some_prefix")).to eq("default string")
        end
      end
    end

    context "when the current_agency is nil" do
      let(:current_agency) { nil }

      it "uses the translation for the default key" do
        expect(helper.agency_translation("some_prefix")).to eq("default string")
      end
    end

    context "when there are variables to interpolate" do
      let(:available_translations) { <<~YAML }
        some_prefix:
          sandbox: some %{variable}
          default: default string
      YAML

      it "interpolates the variables" do
        expect(helper.agency_translation("some_prefix", variable: "string")).to eq("some string")
      end
    end

    context "when the key ends with _html" do
      let(:available_translations) { <<~YAML }
        some_prefix_html:
          sandbox: some %{variable} text
          default: some <strong>bold</strong> text
      YAML

      it "marks the string as HTML safe" do
        without_partial_double_verification do
          allow(helper).to receive(:current_agency).and_return(nil)
        end
        expect(helper.agency_translation("some_prefix_html")).to eq("some <strong>bold</strong> text")
        expect(helper.agency_translation("some_prefix_html")).to be_html_safe
      end

      context "when interpolating a variable" do
        let(:current_agency) { Rails.application.config.client_agencies["sandbox"] }

        it "sanitizes input parameters" do
          expect(helper.agency_translation("some_prefix_html", variable: "<strong>bold</strong>"))
            .to eq("some &lt;strong&gt;bold&lt;/strong&gt; text")
          expect(helper.agency_translation("some_prefix_html")).to be_html_safe
        end

        it "does not sanitize html_safe input parameters" do
          expect(helper.agency_translation("some_prefix_html", variable: "<strong>bold</strong>".html_safe))
            .to eq("some <strong>bold</strong> text")
          expect(helper.agency_translation("some_prefix_html")).to be_html_safe
        end
      end
    end
  end

  describe "#feedback_form_url" do
    let(:current_agency) { nil }
    let(:params) { {} }

    before do
      allow(helper).to receive(:params).and_return(params)
      without_partial_double_verification do
        allow(helper).to receive(:current_agency).and_return(current_agency)
      end
    end

    context "on a CBV flow application page" do
      let(:params) { { controller: "cbv/summaries" } }
      let(:current_agency) { Rails.application.config.client_agencies["sandbox"] }

      it "shows the applicant-facing Google Form" do
        expect(helper.feedback_form_url).to eq(ApplicationHelper::APPLICANT_FEEDBACK_FORM)
      end
    end

    context "on a sandbox caseworker-facing page" do
      let(:params) { { controller: "caseworker/cbv_flow_invitations" } }
      let(:current_agency) { Rails.application.config.client_agencies["sandbox"] }

      it "shows the default feedback form when no caseworker feedback form is configured" do
        expect(helper.feedback_form_url).to eq(ApplicationHelper::APPLICANT_FEEDBACK_FORM)
      end
    end
  end

  describe "#coalesce_to_completed" do
    it "returns succeeded when the status is failed" do
      expect(helper.coalesce_to_completed(:failed)).to eq(:completed)
    end

    it "returns in progress when the status is in progress" do
      expect(helper.coalesce_to_completed(:in_progress)).to eq(:in_progress)
    end
  end

  describe "#get_age_range" do
    let(:now) { Date.new(2025, 5, 15) }

    it "returns nil for invalid date input" do
      expect(helper.get_age_range("invalid-date")).to be_nil
    end

    it "returns nil for invalid date input (from paylocity) before the current day of year" do
      expect(helper.get_age_range("--01-02", now: now)).to be_nil
    end

    it "returns nil for invalid date input (from paylocity)" do
      expect(helper.get_age_range("--12-30", now: now)).to be_nil
    end

    it "returns age range when the date of birth is a string" do
      expect(helper.get_age_range("1990-01-01", now: now)).to eq("30-39")
    end

    it "returns '0-18' for a date of birth 10 years ago" do
      date_of_birth = (Date.today - 10.years)
      expect(helper.get_age_range(date_of_birth, now: now)).to eq("0-18")
    end

    it "returns '19-25' for a date of birth 20 years ago" do
      date_of_birth = (Date.today - 20.years)
      expect(helper.get_age_range(date_of_birth, now: now)).to eq("19-25")
    end

    it "returns '90+' for a date of birth 95 years ago" do
      date_of_birth = (Date.today - 95.years)
      expect(helper.get_age_range(date_of_birth, now: now)).to eq("90+")
    end
  end
end
