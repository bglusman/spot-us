require File.dirname(__FILE__) + '/../spec_helper'

# Be sure to include AuthenticatedTestHelper in spec/spec_helper.rb instead.
# Then, you can remove it from this and the functional test.
include AuthenticatedTestHelper

describe User do
  it { Factory(:user).should have_many(:donations) }
  it { Factory(:user).should have_many(:tips) }
  it { Factory(:user).should have_many(:pitches) }
  it { Factory(:user).should have_many(:pledges) }
  it { Factory(:user).should have_many(:pledges) }

  describe "creating" do
    it "is creatable by guest" do
      User.createable_by?(nil).should be
    end
  end

  describe "editing" do
    before(:each) do
      @user = Factory(:user)
    end

    it "is editable by its self" do
      @user.editable_by?(@user).should be
    end

    it "is not editable by a stranger" do
      @user.editable_by?(Factory(:user)).should_not be_true
    end

    it "is not editable if not logged in" do
      @user.editable_by?(nil).should_not be_true
    end
  end

  it "returns the amount pledged on amount_pledged_to(tip)" do
    user = Factory(:user)
    pledge1 = Factory(:pledge, :user => user, :amount => 1)
    pledge2 = Factory(:pledge, :user => user, :amount => 3)
    user.reload
    user.amount_pledged_to(pledge1.tip).should == pledge1.amount
    user.amount_pledged_to(pledge2.tip).should == pledge2.amount
  end

  it "returns the amount donated on amount_donated_to(pitch)" do
    user = Factory(:user)
    donation1 = Factory(:donation, :user => user, :amount => 1)
    donation2 = Factory(:donation, :user => user, :amount => 3)
    user.reload
    user.amount_donated_to(donation1.pitch).should == donation1.amount
    user.amount_donated_to(donation2.pitch).should == donation2.amount
  end

  describe "signup notification emails" do
    it "sends email to citize on create" do
      user = Factory.build(:user)
      Mailer.should_receive(:deliver_citizen_signup_notification).with(user)
      user.save!
    end
    
    it "sends email for news org when user is a new org on create" do
      user = Factory.build(:organization)
      Mailer.should_receive(:deliver_organization_signup_notification).with(user)
      Mailer.should_receive(:deliver_news_org_signup_request).with(user)
      user.save!
    end
    
    it "sends email for reporter when user is a reporter on create" do
      user = Factory.build(:reporter)
      Mailer.should_receive(:deliver_reporter_signup_notification).with(user)
      user.save!
    end

    it "doesn't send on save" do
      user = Factory(:user)
      user.email = random_email_address
      Mailer.should_not_receive(:deliver_signup_notification).with(user)
      user.save
    end
  end

  describe 'being created' do
    before do
      @user = nil
      @creating_user = lambda do
        @user = Factory(:user)
        violated "#{@user.errors.full_messages.to_sentence}" if @user.new_record?
      end
    end
    
    it 'increments User#count' do
      @creating_user.should change(User, :count).by(1)
    end
  end

  it 'generates password on create' do
    user = Factory(:user, :password => nil)
    violated "#{user.errors.full_messages.to_sentence}" if user.new_record?
    user.password.should_not be_nil
    user.password.size.should == 6
    User.authenticate(user.email, user.password).should == 
      User.find(user.to_param)
  end

  it 'requires password confirmation on update' do
    user = Factory(:user)
    user.update_attributes(:password => 'new password', :password_confirmation => nil)
    user.should_not be_valid
    user.errors.on(:password_confirmation).should_not be_nil
  end

  it "doesn't require password_confirmation on save" do
    user = Factory :user
    user.email = random_email_address
    user.save.should be_true
  end

  it 'requires email' do
    user = Factory.build(:user, :email => nil)
    user.should_not be_valid
    user.errors.on(:email).should_not be_nil
  end

  %w(Citizen Reporter Organization).each do |user_type|
    it "should allow a type of #{user_type}" do
      user = Factory(:user, :type => user_type)
      violated "#{user.errors.full_messages.to_sentence}" if user.new_record?
    end
  end

  it "should not allow a type of BusDriver" do
    user = Factory.build(:user, :type => 'BusDriver')
    user.should_not be_valid
    user.should have(1).error_on(:type)
  end

  it "should require a type" do
    user = Factory.build(:user, :type => nil)
    user.should_not be_valid
    user.should have(1).error_on(:type)
  end

  describe "after being created" do
    before do
      @password = 'test'
      @user = Factory(:user, :email    => 'user@example.com',
                             :password => @password)
      @user = User.find(@user.to_param) # clear instance vars and get correct type
    end

    it 'changes password' do
      @user.update_attributes(:password => 'new password', :password_confirmation => 'new password')
      User.authenticate('user@example.com', 'new password').should == @user
    end

    it 'does not rehash password' do
      @user.update_attributes!(:email => 'quentin2@example.com')
      User.authenticate('quentin2@example.com', @password).should == @user
    end

    it 'is found by correct authentication' do
      User.authenticate('user@example.com', @password).should == @user
    end

    it 'sets remember token' do
      @user.remember_me
      @user.remember_token.should_not be_nil
      @user.remember_token_expires_at.should_not be_nil
    end

    it 'unsets remember token' do
      @user.remember_me
      @user.remember_token.should_not be_nil
      @user.forget_me
      @user.remember_token.should be_nil
    end

    it 'remembers me for one week' do
      before = 1.week.from_now.utc
      @user.remember_me_for 1.week
      after = 1.week.from_now.utc
      @user.remember_token.should_not be_nil
      @user.remember_token_expires_at.should_not be_nil
      @user.remember_token_expires_at.between?(before, after).should be_true
    end

    it 'remembers me until one week' do
      time = 1.week.from_now.utc
      @user.remember_me_until time
      @user.remember_token.should_not be_nil
      @user.remember_token_expires_at.should_not be_nil
      @user.remember_token_expires_at.should == time
    end

    it 'remembers me default two weeks' do
      before = 2.weeks.from_now.utc
      @user.remember_me
      after = 2.weeks.from_now.utc
      @user.remember_token.should_not be_nil
      @user.remember_token_expires_at.should_not be_nil
      @user.remember_token_expires_at.between?(before, after).should be_true
    end

    it "resets the password" do
      @old_crypted_password = @user.crypted_password
      @user.reset_password!
      @user.reload
      @user.crypted_password.should_not == @old_crypted_password
    end

    it "sends a password reset email" do
      Mailer.should_receive(:deliver_password_reset_notification).with(@user).once
      @user.reset_password!
    end

    it "should set the default location to the first location" do
      @user.location.should == LOCATIONS.first
    end
  end

  it "should require acceptance of terms of service" do
    user = Factory.build(:user, :terms_of_service => '0')
    user.should_not be_valid
    user.should have(1).error_on(:terms_of_service)
  end

  it "requires first name" do
    user = Factory.build(:user, :first_name => nil)
    user.should_not be_valid
    user.should have(1).error_on(:first_name)
  end

  it "requires last name" do
    user = Factory.build(:user, :last_name => nil)
    user.should_not be_valid
    user.should have(1).error_on(:last_name)
  end
  
  it "should have a photo attachment" do
    Factory(:user).photo.should be_instance_of(Paperclip::Attachment)
  end

  it "should allow a valid region for location" do
    user = Factory(:user)
    LOCATIONS.each do |location|
      user.location = location
      user.should be_valid
    end
  end

  it "should allow a blank location" do
    user = Factory.build(:user, :location => nil)
    user.should be_valid
  end

  it "should not allow invalid regions for location" do
    user = Factory.build(:user, :location => 'Mars')
    user.should_not be_valid
    user.should have(1).error_on(:location)
  end

  it "should combine the first and last name for full name" do
    user = Factory(:user, :first_name => 'First', :last_name => 'Second')
    user.full_name.should == 'First Second'
  end
  
  it "should allow a url starting with http" do
    user = Factory.build(:user, :website => "http://something")
    user.should be_valid
  end
  
  it "should not allow a url that does not start with http" do
    user = Factory.build(:user, :website => "bob")
    user.should_not be_valid
    user.should have(1).error_on(:website)
  end
  
  it "should allow for the website to be blank" do
    user = Factory.build(:user, :website => nil)
    user.should be_valid
  end

  describe "updating a user's donation amounts with valid amounts" do
    before do
      @user = Factory(:user)
      @changed_unpaid = Factory(:donation, :user => @user, :paid => false, :amount => 5)
      @unchanged_unpaid = Factory(:donation, :user => @user, :paid => false, :amount => 15)
      @paid = Factory(:donation, :user => @user, :paid => true, :amount => 25)
    end

    it "should update an unpaid amount that had a new value" do
      lambda { do_update }.should change { @changed_unpaid.amount }
    end

    it "should not update an unpaid amount that didn't have a new value" do
      lambda { do_update }.should_not change { @unchanged_unpaid.amount }
    end

    it "should not update a paid amount" do
      lambda { do_update }.should_not change { @paid.amount }
    end

    def do_update
      @user.donation_amounts = { @changed_unpaid.id => 10,
                                 @paid.id           => 20,
                                 0                  => 30 }
      @user.save
      @paid.reload
      @changed_unpaid.reload
      @unchanged_unpaid.reload
    end
  end

  describe "updating a user's donation amounts with invalid amounts" do
    before do
      @user = Factory(:user)
      @donation = Factory(:donation, :user => @user, :amount => 5, :paid => false)
    end

    it "should not change the donation amount" do
      lambda { do_update }.should_not change { @donation.amount }
    end

    it "should add validation errors to the user" do
      do_update
      @user.should_not be_valid
    end

    it "should add an error to base" do
      do_update
      @user.should have(1).error_on(:base)
    end

    def do_update
      @user.donation_amounts = { @donation.id => -1 }
      @user.save
      @donation.reload
    end
  end

  describe "with a donation for a pitch" do
    before do
      @user = Factory(:user)
      @pitch = Factory(:pitch)
      @donation = Factory(:donation, :user => @user, :pitch => @pitch)
    end

    it "should know that the user has donated to that pitch" do
      @user.has_donation_for?(@pitch).should be_true
    end
  end

  describe "without a donation for a pitch" do
    before do
      @user = Factory(:user)
      if @user.donations.detect {|donation| donation.pitch == @pitch }
        violated "the user should not have any donations for the pitch"
      end

      @pitch = Factory(:pitch)
    end

    it "should know that the user hasn't donated to that pitch" do
      @user.has_donation_for?(@pitch).should be_false
    end
  end
end
