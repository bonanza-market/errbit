describe NoticeFingerprinter, type: 'model' do
  let(:fingerprinter) { described_class.new }
  let(:notice) { Fabricate(:notice) }
  let(:backtrace) { Fabricate(:backtrace) }

  context '#generate' do
    it 'generates the same fingerprint for the same notice' do
      f1 = fingerprinter.generate('123', notice, backtrace)
      f2 = fingerprinter.generate('123', notice, backtrace)
      expect(f1).to eq(f2)
    end

    %w(error_class message component action environment_name).each do |i|
      it "affects the fingerprint when #{i} is false" do
        f1 = fingerprinter.generate('123', notice, backtrace)
        f2 = fingerprinter.generate('123', notice, backtrace)

        fingerprinter.send((i << '=').to_sym, false)
        f3 = fingerprinter.generate('123', notice, backtrace)

        expect(f1).to eq(f2)
        expect(f1).to_not eq(f3)
      end
    end

    it 'affects the fingerprint with different backtrace_lines config' do
      f1 = fingerprinter.generate('123', notice, backtrace)
      f2 = fingerprinter.generate('123', notice, backtrace)

      fingerprinter.backtrace_lines = 2
      f3 = fingerprinter.generate('123', notice, backtrace)

      expect(f1).to eq(f2)
      expect(f1).to_not eq(f3)
    end

    context 'two backtraces have the same first two lines' do
      let(:backtrace1) { Fabricate(:backtrace) }
      let(:backtrace2) { Fabricate(:backtrace) }

      before do
        backtrace1.lines[0] = backtrace2.lines[0]
        backtrace1.lines[1] = backtrace2.lines[1]
        backtrace1.lines[2] = { number: 1, file: '[PROJECT_ROOT]/a', method: :b }
      end

      it 'has the same fingerprint when only considering two lines' do
        fingerprinter.backtrace_lines = 2
        f1 = fingerprinter.generate('123', notice, backtrace1)
        f2 = fingerprinter.generate('123', notice, backtrace2)

        expect(f1).to eq(f2)
      end

      it 'has a different fingerprint when considering three lines' do
        fingerprinter.backtrace_lines = 3
        f1 = fingerprinter.generate('123', notice, backtrace1)
        f2 = fingerprinter.generate('123', notice, backtrace2)

        expect(f1).to_not eq(f2)
      end
    end

    context "two notices with no backtrace" do
      it "has the same fingerprint" do
        f1 = fingerprinter.generate('123', notice, nil)
        f2 = fingerprinter.generate('123', notice, nil)

        expect(f1).to eq(f2)
      end
    end

    context 'two notices differing only by an ID in the message' do
      let(:notice1) { Fabricate(:notice, message: 'Something happened ID=1') }
      let(:notice2) { Fabricate(:notice, message: 'Something happened ID=2') }

      it 'has the same fingerprint' do
        f1 = fingerprinter.generate('123', notice1, backtrace)
        f2 = fingerprinter.generate('123', notice2, backtrace)
        expect(f1).to eq(f2)
      end
    end

    context 'two notices differing only by a long number at the start the message' do
      let(:notice1) { Fabricate(:notice, message: "8600002000 is out of range for ActiveMo[Truncated]") }
      let(:notice2) { Fabricate(:notice, message: "8800000000 is out of range for ActiveMo[Truncated]") }

      it 'has the same fingerprint' do
        f1 = fingerprinter.generate('123', notice1, backtrace)
        f2 = fingerprinter.generate('123', notice2, backtrace)
        expect(f1).to eq(f2)
      end
    end

    context 'two notices differing only by a long number in the message' do
      let(:notice1) { Fabricate(:notice, message: %(something happened for "custom_category_id=511&per_page=48":String)) }
      let(:notice2) { Fabricate(:notice, message: %(something happened for "custom_category_id=434&per_page=48":String)) }

      it 'has the same fingerprint' do
        f1 = fingerprinter.generate('123', notice1, backtrace)
        f2 = fingerprinter.generate('123', notice2, backtrace)
        expect(f1).to eq(f2)
      end
    end

    context 'two notices differing only by a short number in the message' do
      let(:notice1) { Fabricate(:notice, message: %(something happened for "custom_category_id=11&per_page=48":String)) }
      let(:notice2) { Fabricate(:notice, message: %(something happened for "custom_category_id=34&per_page=48":String)) }

      it 'has a different fingerprint' do
        f1 = fingerprinter.generate('123', notice1, backtrace)
        f2 = fingerprinter.generate('123', notice2, backtrace)
        expect(f1).to_not eq(f2)
      end
    end

    context 'two Mysql2::Error notices differing only by a duplicate entry ID in the message' do
      let(:notice1) { Fabricate(:notice, message: "Mysql2::Error: Duplicate entry '1' for key 'index_some_table_on_something") }
      let(:notice2) { Fabricate(:notice, message: "Mysql2::Error: Duplicate entry '2' for key 'index_some_table_on_something") }

      it 'has the same fingerprint' do
        f1 = fingerprinter.generate('123', notice1, backtrace)
        f2 = fingerprinter.generate('123', notice2, backtrace)
        expect(f1).to eq(f2)
      end
    end

    context 'two Mysql2::Error notices differing only by the content of a query' do
      let(:notice1) { Fabricate(:notice, message: 'Mysql2::Error: Timeout waiting for a response from the last query. (waited 15 seconds): UPDATE `some_table` SET `some_value` = 1 WHERE `some_table`.`id` = 1') }
      let(:notice2) { Fabricate(:notice, message: 'Mysql2::Error: Timeout waiting for a response from the last query. (waited 15 seconds): UPDATE `some_table` SET `some_value` = 2 WHERE `some_table`.`id` = 2') }

      it 'has the same fingerprint' do
        f1 = fingerprinter.generate('123', notice1, backtrace)
        f2 = fingerprinter.generate('123', notice2, backtrace)
        expect(f1).to eq(f2)
      end
    end

    context 'two NoMethodError notices differing only by the inspected value' do
      let(:notice1) { Fabricate(:notice, message: "undefined method `beginnning_of_day' for Wed, 13 Jun 2018 01:15:14 PDT -07:00:Time") }
      let(:notice2) { Fabricate(:notice, message: "undefined method `beginnning_of_day' for Wed, 13 Jun 2018 02:15:14 PDT -07:00:Time") }

      it 'has the same fingerprint' do
        f1 = fingerprinter.generate('123', notice1, backtrace)
        f2 = fingerprinter.generate('123', notice2, backtrace)
        expect(f1).to eq(f2)
      end
    end
  end
end
