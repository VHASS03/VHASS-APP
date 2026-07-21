// Generate 6-digit OTP
const generateOTP = () => Math.floor(100000 + Math.random() * 900000).toString();

// Send OTP via Socket.IO (no SMS gateway)
const sendOTP = async (phoneNumber, io) => {
  const otp = generateOTP();

  // Emit to OTP room if socket server is available
  if (io) {
    const otpRoom = `otp:${phoneNumber}`;
    io.to(otpRoom).emit('auth:otp-received', {
      phone: phoneNumber,
      otp,
      expiresIn: 600,
      message: `Your VHASS verification code is: ${otp}. Valid for 10 minutes.`,
    });
    console.log(`📡 OTP emitted via Socket.IO to ${otpRoom}: ${otp}`);
  }

  // Always log on server for debugging in development
  console.log(`📱 OTP for ${phoneNumber}: ${otp}`);

  return { success: true, otp, message: 'OTP sent via Socket.IO' };
};

module.exports = { generateOTP, sendOTP };


