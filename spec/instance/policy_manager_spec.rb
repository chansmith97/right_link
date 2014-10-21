#--
# Copyright (c) 2012 RightScale, Inc, All Rights Reserved Worldwide.
#
# THIS PROGRAM IS CONFIDENTIAL AND PROPRIETARY TO RIGHTSCALE
# AND CONSTITUTES A VALUABLE TRADE SECRET.  Any unauthorized use,
# reproduction, modification, or disclosure of this program is
# strictly prohibited.  Any use of this program by an authorized
# licensee is strictly subject to the terms and conditions,
# including confidentiality obligations, set forth in the applicable
# License Agreement between RightScale, Inc. and
# the licensee.
#++

require File.expand_path('../spec_helper', __FILE__)

module RightScale
  class PolicyManager
    class << self
      def reset
        @policies.clear
      end
      def get_policy(bundle)
        get_policy_from_bundle(bundle)
      end
    end
  end
end

describe RightScale::PolicyManager do
  let(:policy_name)       {'foo'}
  let(:bundle_nil_policy) {flexmock('bundle', :runlist_policy => nil) }

  before(:each) do
    RightScale::PolicyManager.reset
  end

  context 'when the given bundle is nil' do
    it 'register' do
      RightScale::PolicyManager.register(nil).should be_false
    end
    it 'success should return false' do
      RightScale::PolicyManager.success(nil).should be_false
    end
    it 'fail should return false' do
      RightScale::PolicyManager.fail(nil).should be_false
    end
    it 'get_audit should return nil' do
      RightScale::PolicyManager.get_audit(nil).should be_nil
    end
  end

  context 'when the given bundle has a nil runlist policy' do
    it 'register' do
      RightScale::PolicyManager.register(nil).should be_false
    end
    it 'success should return false' do
      RightScale::PolicyManager.success(bundle_nil_policy).should be_false
    end
    it 'fail should return false' do
      RightScale::PolicyManager.fail(bundle_nil_policy).should be_false
    end
    it 'get_audit should return nil' do
      RightScale::PolicyManager.get_audit(bundle_nil_policy).should be_nil
    end
  end

  let(:bundle)      {flexmock('bundle', :audit_id => rand**32, :runlist_policy => flexmock('rlp', :policy_name => policy_name, :audit_period => 120)) }

  context 'when a policy has not been registered' do
    it 'registered? should return false' do
      RightScale::PolicyManager.registered?(bundle).should be_false
    end
    it 'success should return false' do
      RightScale::PolicyManager.success(bundle).should be_false
    end
    it 'fail should return false' do
      RightScale::PolicyManager.fail(bundle).should be_false
    end
    it 'get_audit should return nil' do
      RightScale::PolicyManager.get_audit(bundle).should be_nil
    end
  end

  context 'when a policy has been registered' do
    let(:audit_proxy) {flexmock('audit', :audit_id => rand**32)}

    before do
      audit_proxy.should_receive(:append_info).once.with(/First run of Reconvergence Policy '#{policy_name}' at .*/)
      flexmock(RightScale::AuditProxy).should_receive(:create).and_yield(audit_proxy)
      RightScale::PolicyManager.register(bundle)
    end

    it 'get_audit should return the audit assigned to the existing policy' do
      RightScale::PolicyManager.get_audit(bundle).should_not be_nil
    end

    it 'registered? should return true' do
      RightScale::PolicyManager.registered?(bundle).should be_true
    end

    context :success do
      it 'should return true' do
        RightScale::PolicyManager.success(bundle).should be_true
      end

      it 'should increment the policy count' do
        RightScale::PolicyManager.success(bundle)
        RightScale::PolicyManager.success(bundle)
        RightScale::PolicyManager.success(bundle)
        RightScale::PolicyManager.get_policy(bundle).count.should == 3
      end

      context 'and the period since last audit has elapsed' do
        before do
          # ensure audit count is greater than one to start
          RightScale::PolicyManager.success(bundle)

          # sleep to ensure timestamps will not match
          sleep(0.1)

          # update the period so we dont have to wait so long
          existing_policy = RightScale::PolicyManager.get_policy(bundle)
          existing_policy.audit_period = Time.now - existing_policy.audit_timestamp

          # success is going to audit now
          audit_proxy.should_receive(:append_info).once.with(/Reconvergence Policy '#{policy_name}' has run successfully .* times since .*/)
        end

        it 'should update the last audit time stamp of the policy' do
          current_timestamp = RightScale::PolicyManager.get_policy(bundle).audit_timestamp
          RightScale::PolicyManager.success(bundle)
          RightScale::PolicyManager.get_policy(bundle).audit_timestamp.should > current_timestamp
        end

        it 'should reset the count' do
          RightScale::PolicyManager.get_policy(bundle).count.should == 1
          RightScale::PolicyManager.success(bundle)
          RightScale::PolicyManager.get_policy(bundle).count.should == 0
        end
      end

      context :fail do
        it 'should return true' do
          RightScale::PolicyManager.fail(bundle).should be_true
        end

        it 'should reset the count' do
          RightScale::PolicyManager.success(bundle)
          RightScale::PolicyManager.get_policy(bundle).count.should == 1
          RightScale::PolicyManager.fail(bundle)
          RightScale::PolicyManager.get_policy(bundle).count.should == 0
        end
      end
    end
  end
end