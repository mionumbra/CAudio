/* began */

function caudio_flac() {
	static helper = {
		parseStreamInfo: function(_br) {
			var minBlock = (_br.readBits(16));
			var maxBlock = (_br.readBits(16));
			var minFrame = (_br.readBits(24));
			var maxFrame = (_br.readBits(24));
			var sampleRate = (_br.readBits(20));
			var channels = ((_br.readBits(3)) + 1);
			var bits = ((_br.readBits(5)) + 1);
			var totalSamples = (_br.readBits(36));
			_br.skipBits(128);
			return({
				minBlock: minBlock,
				maxBlock: maxBlock,
				minFrame: minFrame,
				maxFrame: maxFrame,
				sampleRate: sampleRate,
				channels: channels,
				bits: bits,
				totalSamples: totalSamples,
			});
		},
		
		parseHeader: function(_path, _fullLoad = false) {
			var _id_bf = (file_bin_open(_path, 0));
			if (_id_bf < 0) {
				show_debug_message("[CAudio] [FLAC] E: Cannot open file.");
				return(-1);
			};
			var _len = (file_bin_size(_id_bf));
			file_bin_close(_id_bf);
			if (_len < 42) {
				show_debug_message("[CAudio] [FLAC] E: File too small.");
				return(-1);
			};
			
			// Buffer sounds need the full file; streams only probe metadata.
			var probe = (_fullLoad ? _len : min(_len, 8 * 1024 * 1024));
			var _id_b = (buffer_create(probe, buffer_fixed, 1));
			buffer_load_partial(_id_b, _path, 0, probe, 0);
			var _br = (new CAudioBitReader(_id_b, _path, 0, _len, !_fullLoad));
			
			var _magic = (_br.readBits(32));
			if (_magic != 0x664C6143) {
				show_debug_message("[CAudio] [FLAC] E: Not a valid FLAC file.");
				_br.destroy();
				return(-1);
			};
			
			var streamInfo = undefined;
			var seekPoints = [];
			var last = false;
			while (!last) {
				last = (bool(_br.readBits(1)));
				var typ = (_br.readBits(7));
				var sz = (_br.readBits(24));
				var startAbs = (_br.tellBits());
				if (startAbs + (sz * 8) > (_len * 8)) {
					show_debug_message("[CAudio] [FLAC] E: Truncated metadata block.");
					_br.destroy();
					return(-1);
				};
				if (typ == 0) {
					if (sz < 34) {
						show_debug_message("[CAudio] [FLAC] E: STREAMINFO too small.");
						_br.destroy();
						return(-1);
					};
					streamInfo = (self.parseStreamInfo(_br));
				} elif (typ == 3) {
					// SEEKTABLE: 18 bytes per point
					var nPts = (sz div 18);
					var spIndex = 0; while (spIndex < nPts) {
						var spHi = (_br.readBits(32));
						var spLo = (_br.readBits(32));
						var offHi = (_br.readBits(32));
						var offLo = (_br.readBits(32));
						var spN = (_br.readBits(16));
						// placeholder: sample number all 1-bits
						if ((spHi == 0xFFFFFFFF) && (spLo == 0xFFFFFFFF)) {
							spIndex += 1;
							continue;
						};
						// sample/offset fit in 53-bit mantissa for normal files
						var spSample = ((spHi * 4294967296) + spLo);
						var spOffset = ((offHi * 4294967296) + offLo);
						array_push(seekPoints, { sample: spSample, offset: spOffset, nSamples: spN });
						spIndex += 1;
					};
					// consume trailing padding if any
					var consumed = (nPts * 18);
					if (consumed < sz) then _br.skipBits((sz - consumed) * 8);
				} else {
					_br.skipBits(sz * 8);
				};
				var endAbs = (startAbs + (sz * 8));
				var curAbs = (_br.tellBits());
				if (curAbs < endAbs) then _br.skipBits(endAbs - curAbs);
				elif (curAbs > endAbs) {
					show_debug_message("[CAudio] [FLAC] E: Metadata overread.");
					_br.destroy();
					return(-1);
				};
			};
			
			if (!is_struct(streamInfo)) {
				show_debug_message("[CAudio] [FLAC] E: Missing STREAMINFO.");
				_br.destroy();
				return(-1);
			};
			if ((streamInfo.sampleRate <= 0) || (streamInfo.channels <= 0) || (streamInfo.bits <= 0)) {
				show_debug_message("[CAudio] [FLAC] E: Invalid STREAMINFO fields.");
				_br.destroy();
				return(-1);
			};
			
			var firstFrameByte = (_br.tell());
			if (firstFrameByte + 4 > _len) {
				show_debug_message("[CAudio] [FLAC] E: Missing audio frames.");
				_br.destroy();
				return(-1);
			};
			var duration = ((streamInfo.totalSamples > 0) ? ((streamInfo.totalSamples) / (streamInfo.sampleRate)) : 0);
			
			// The full-load reader already owns the complete file buffer.
			if (_fullLoad) {
				_br.seek(firstFrameByte);
				return({
					streamInfo: streamInfo,
					bitReader: _br,
					firstFrameByte: firstFrameByte,
					fileSize: _len,
					channels: (streamInfo.channels),
					sampleRate: (streamInfo.sampleRate),
					bits: (streamInfo.bits),
					totalSamples: (streamInfo.totalSamples),
					duration: duration,
					minBlock: (streamInfo.minBlock),
					maxBlock: (streamInfo.maxBlock),
					path: _path,
					windowed: false,
					seekPoints: seekPoints,
				});
			};
			
			// streaming: keep windowed reader positioned at first frame
			_br.seek(firstFrameByte);
			return({
				streamInfo: streamInfo,
				bitReader: _br,
				firstFrameByte: firstFrameByte,
				fileSize: _len,
				channels: (streamInfo.channels),
				sampleRate: (streamInfo.sampleRate),
				bits: (streamInfo.bits),
				totalSamples: (streamInfo.totalSamples),
				duration: duration,
				minBlock: (streamInfo.minBlock),
				maxBlock: (streamInfo.maxBlock),
				path: _path,
				windowed: true,
				seekPoints: seekPoints,
			});
		},
				parseAudioChannelType: function(_channels) {
			switch (_channels) {
				case(1): return(audio_mono);
				case(2): return(audio_stereo);
				case(6):
					show_debug_message("[CAudio] [FLAC] W: 5.1 audio actually not supported, but nothing needs to do.");
					return(audio_3d);
				default:
					show_debug_message("[CAudio] [FLAC] E: Unsupported numOfChannel, fallback to audio_stereo.");
					return(audio_stereo);
			};
		},
		
		parseBufferDataType: function(_bits) {
			if (_bits <= 8) then return(buffer_u8);
			if (_bits <= 16) then return(buffer_s16);
			show_debug_message("[CAudio] [FLAC] W: bits>16 will be downmixed to s16 for GameMaker playback.");
			return(buffer_s16);
		},
		
		readUtf8Uint: function(_br) {
			var x0 = (_br.readBits(8));
			if ((x0 & 0x80) == 0) then return(x0);
			var n = 0;
			var mask = 0x40;
			while ((x0 & mask) != 0) {
				n += 1;
				mask = (mask >> 1);
				if (n > 6) then return(-1);
			};
			if (n == 0) then return(-1);
			var v = (x0 & ((1 << (6 - n)) - 1));
			repeat (n) {
				var xb = (_br.readBits(8));
				if ((xb & 0xC0) != 0x80) then return(-1);
				v = ((v << 6) | (xb & 0x3F));
			};
			return(v);
		},
		
		crc8Table: function() {
			static t = undefined;
			if (is_undefined(t)) {
				t = (array_create(256));
				var i = 0; while (i < 256) {
					var crc = i;
					var b = 0; while (b < 8) {
						if ((crc & 0x80) != 0) then crc = (((crc << 1) & 0xFF) ^ 0x07);
						else crc = ((crc << 1) & 0xFF);
						b += 1;
					};
					t[i] = crc;
					i += 1;
				};
			};
			return(t);
		},
		
		crc16Table: function() {
			static t = undefined;
			if (is_undefined(t)) {
				t = (array_create(256));
				var i = 0; while (i < 256) {
					var crc = ((i << 8) & 0xFFFF);
					var b = 0; while (b < 8) {
						if ((crc & 0x8000) != 0) then crc = (((crc << 1) & 0xFFFF) ^ 0x8005);
						else crc = ((crc << 1) & 0xFFFF);
						b += 1;
					};
					t[i] = crc;
					i += 1;
				};
			};
			return(t);
		},
		
		calcCrc8: function(_buf, _off, _len) {
			static table = undefined;
			if (is_undefined(table)) then table = (self.crc8Table());
			var crc = 0;
			var i = 0; while (i < _len) {
				crc = (table[crc ^ (buffer_peek(_buf, _off + i, buffer_u8))]);
				i += 1;
			};
			return(crc);
		},
		
		calcCrc16: function(_buf, _off, _len) {
			static table = undefined;
			if (is_undefined(table)) then table = (self.crc16Table());
			var crc = 0;
			var i = 0; while (i < _len) {
				crc = (((crc << 8) & 0xFFFF) ^ (table[((crc >> 8) ^ (buffer_peek(_buf, _off + i, buffer_u8))) & 0xFF]));
				i += 1;
			};
			return(crc & 0xFFFF);
		},
		
		readRiceSigned: function(_br, _param) {
			var q = (_br.readUnaryZeroes());
			if (is_undefined(q)) then return(undefined);
			var r = 0;
			if (_param > 0) then r = (_br.readBits(_param));
			var u = ((q << _param) | r);
			if ((u & 1) != 0) then return(-((u >> 1) + 1));
			return(u >> 1);
		},
		
		decodeResiduals: function(_br, _order, _blockSize, _residual) {
			var residualMethod = (_br.readBits(2));
			if ((residualMethod != 0) && (residualMethod != 1)) {
				show_debug_message($"[CAudio] [FLAC] E: Unsupported residual method { residualMethod }.");
				return(false);
			};
			var riceBits = ((residualMethod == 0) ? 4 : 5);
			var escape = ((residualMethod == 0) ? 15 : 31);
			var partOrder = (_br.readBits(4));
			var partitions = (1 << partOrder);
			var partSamples = (_blockSize >> partOrder);
			if ((partSamples * partitions) != _blockSize) {
				show_debug_message("[CAudio] [FLAC] E: Invalid residual partition.");
				return(false);
			};
			if ((partSamples < _order) && (partitions > 0)) {
				show_debug_message("[CAudio] [FLAC] E: Residual partition smaller than predictor order.");
				return(false);
			};
			
			// residual[0..order-1] already holds warm-up; coded residuals start at order
			var sample = _order;
			var p = 0; while (p < partitions) {
				var partBegin = ((p == 0) ? _order : 0);
				var count = (partSamples - partBegin);
				var riceParam = (_br.readBits(riceBits));
				if (riceParam == escape) {
					var bits = (_br.readBits(5));
					var i = 0; while (i < count) {
						_residual[sample] = (_br.readSignedBits(bits));
						sample += 1;
						i += 1;
					};
				} else {
					var i = 0; while (i < count) {
						var v = (self.readRiceSigned(_br, riceParam));
						if (is_undefined(v)) then return(false);
						_residual[sample] = v;
						sample += 1;
						i += 1;
					};
				};
				p += 1;
			};
			if (sample != _blockSize) {
				show_debug_message($"[CAudio] [FLAC] E: Residual count mismatch { sample } != { _blockSize }.");
				return(false);
			};
			return(true);
		},
		
		restoreFixed: function(_order, _blockSize, _residual, _out) {
			var i = 0; while (i < _order) {
				_out[i] = (_residual[i]);
				i += 1;
			};
			switch (_order) {
				case(0):
					i = 0; while (i < _blockSize) {
						_out[i] = (_residual[i]);
						i += 1;
					};
					break;
				case(1):
					i = 1; while (i < _blockSize) {
						_out[i] = ((_residual[i]) + (_out[i - 1]));
						i += 1;
					};
					break;
				case(2):
					i = 2; while (i < _blockSize) {
						_out[i] = ((_residual[i]) + ((2 * (_out[i - 1])) - (_out[i - 2])));
						i += 1;
					};
					break;
				case(3):
					i = 3; while (i < _blockSize) {
						_out[i] = ((_residual[i]) + ((3 * (_out[i - 1])) - (3 * (_out[i - 2])) + (_out[i - 3])));
						i += 1;
					};
					break;
				case(4):
					i = 4; while (i < _blockSize) {
						_out[i] = ((_residual[i]) + ((4 * (_out[i - 1])) - (6 * (_out[i - 2])) + (4 * (_out[i - 3])) - (_out[i - 4])));
						i += 1;
					};
					break;
				default:
					return(false);
			};
			return(true);
		},
		
		restoreLpc: function(_order, _blockSize, _qlp, _shift, _residual, _out) {
			var i = 0; while (i < _order) {
				_out[i] = (_residual[i]);
				i += 1;
			};
			i = _order; while (i < _blockSize) {
				var sum = int64(0);
				var j = 0; while (j < _order) {
					sum += (int64(_qlp[j]) * int64(_out[i - 1 - j]));
					j += 1;
				};
				if (_shift > 0) {
					sum = (sum >> _shift);
				} elif (_shift < 0) {
					sum = (sum << -_shift);
				};
				_out[i] = (real(sum) + (_residual[i]));
				i += 1;
			};
			return(true);
		},
		
		decodeSubframe: function(_br, _bps, _blockSize, _out, _residual) {
			if ((_br.readBits(1)) != 0) {
				show_debug_message("[CAudio] [FLAC] E: Subframe padding bit set.");
				return(false);
			};
			var typeCode = (_br.readBits(6));
			var wasted = 0;
			if ((_br.readBits(1)) != 0) {
				wasted = 1;
				while ((_br.readBits(1)) == 0) {
					wasted += 1;
					if (wasted > 32) {
						show_debug_message("[CAudio] [FLAC] E: Wasted bits overflow.");
						return(false);
					};
				};
			};
			var bps = (_bps - wasted);
			if (bps <= 0) {
				show_debug_message("[CAudio] [FLAC] E: Invalid subframe bps.");
				return(false);
			};
			
			if (typeCode == 0) {
				var c = (_br.readSignedBits(bps));
				var i = 0; while (i < _blockSize) {
					_out[i] = c;
					i += 1;
				};
			} elif (typeCode == 1) {
				var i = 0; while (i < _blockSize) {
					_out[i] = (_br.readSignedBits(bps));
					i += 1;
				};
			} elif ((typeCode >= 8) && (typeCode <= 12)) {
				var residual = _residual;
				if (!is_array(residual) || (array_length(residual) < _blockSize)) then residual = (array_create(_blockSize));
				var order = (typeCode - 8);
				var i = 0; while (i < order) {
					residual[i] = (_br.readSignedBits(bps));
					i += 1;
				};
				if (!(self.decodeResiduals(_br, order, _blockSize, residual))) then return(false);
				if (!(self.restoreFixed(order, _blockSize, residual, _out))) then return(false);
			} elif ((typeCode >= 32) && (typeCode <= 63)) {
				var residual = _residual;
				if (!is_array(residual) || (array_length(residual) < _blockSize)) then residual = (array_create(_blockSize));
				var order = ((typeCode - 32) + 1);
				var i = 0; while (i < order) {
					residual[i] = (_br.readSignedBits(bps));
					i += 1;
				};
				var precision = ((_br.readBits(4)) + 1);
				if (precision == 16) {
					show_debug_message("[CAudio] [FLAC] E: Invalid QLP precision.");
					return(false);
				};
				var shift = (_br.readSignedBits(5));
				var qlp = (array_create(order));
				i = 0; while (i < order) {
					qlp[i] = (_br.readSignedBits(precision));
					i += 1;
				};
				if (!(self.decodeResiduals(_br, order, _blockSize, residual))) then return(false);
				if (!(self.restoreLpc(order, _blockSize, qlp, shift, residual, _out))) then return(false);
			} else {
				show_debug_message($"[CAudio] [FLAC] E: Unsupported subframe type { typeCode }.");
				return(false);
			};
			
			if (wasted > 0) {
				var i = 0; while (i < _blockSize) {
					_out[i] = ((_out[i]) << wasted);
					i += 1;
				};
			};
			return(true);
		},
		
		decodeFrame: function(_br, _streamInfo, _channelBufs, _verifyCrc = true, _residualBufs = undefined) {
			_br.alignByte();
			if (_br.bytesLeft() < 4) then return(0);
			
			var frameStartAbs = (_br.tell());
			var sync = (_br.readBits(14));
			if (sync != 0x3FFE) {
				// resync: walk bytes for next frame
				var walk = (frameStartAbs + 1);
				while (walk + 1 < (_br.fileSize)) {
					_br.seek(walk);
					if ((_br.bytesLeft()) < 2) then break;
					_br.ensure(2);
					var b0 = (buffer_peek(_br.buffer, _br.bytePos, buffer_u8));
					if (b0 == 0xFF) {
						var b1 = (buffer_peek(_br.buffer, _br.bytePos + 1, buffer_u8));
						if ((b1 & 0xFC) == 0xF8) {
							frameStartAbs = walk;
							_br.seek(walk);
							sync = (_br.readBits(14));
							break;
						};
					};
					walk += 1;
				};
				if (sync != 0x3FFE) then return(0);
			};
			
			var reserved0 = (_br.readBits(1));
			if (reserved0 != 0) {
				show_debug_message("[CAudio] [FLAC] E: Frame reserved bit set.");
				return(-1);
			};
			var blockingStrategy = (_br.readBits(1));
			var blockSizeCode = (_br.readBits(4));
			var sampleRateCode = (_br.readBits(4));
			var channelAssign = (_br.readBits(4));
			var sampleSizeCode = (_br.readBits(3));
			var reserved1 = (_br.readBits(1));
			if (reserved1 != 0) {
				show_debug_message("[CAudio] [FLAC] E: Frame reserved2 bit set.");
				return(-1);
			};
			
			var codedNumber = (self.readUtf8Uint(_br));
			if (codedNumber < 0) {
				show_debug_message("[CAudio] [FLAC] E: Bad frame number coding.");
				return(-1);
			};
			
			var blockSize = 0;
			switch (blockSizeCode) {
				case(0):
					show_debug_message("[CAudio] [FLAC] E: Reserved block size code.");
					return(-1);
				case(1): blockSize = 192; break;
				case(2): case(3): case(4): case(5):
					blockSize = (576 << (blockSizeCode - 2));
					break;
				case(6):
					blockSize = ((_br.readBits(8)) + 1);
					break;
				case(7):
					blockSize = ((_br.readBits(16)) + 1);
					break;
				default:
					blockSize = (256 << (blockSizeCode - 8));
					break;
			};
			
			var sampleRate = (_streamInfo.sampleRate);
			switch (sampleRateCode) {
				case(0): break;
				case(1): sampleRate = 88200; break;
				case(2): sampleRate = 176400; break;
				case(3): sampleRate = 192000; break;
				case(4): sampleRate = 8000; break;
				case(5): sampleRate = 16000; break;
				case(6): sampleRate = 22050; break;
				case(7): sampleRate = 24000; break;
				case(8): sampleRate = 32000; break;
				case(9): sampleRate = 44100; break;
				case(10): sampleRate = 48000; break;
				case(11): sampleRate = 96000; break;
				case(12): sampleRate = ((_br.readBits(8)) * 1000); break;
				case(13): sampleRate = (_br.readBits(16)); break;
				case(14): sampleRate = ((_br.readBits(16)) * 10); break;
				default:
					show_debug_message("[CAudio] [FLAC] E: Invalid sample rate code.");
					return(-1);
			};
			
			var bits = (_streamInfo.bits);
			switch (sampleSizeCode) {
				case(0): break;
				case(1): bits = 8; break;
				case(2): bits = 12; break;
				case(4): bits = 16; break;
				case(5): bits = 20; break;
				case(6): bits = 24; break;
				case(7): bits = 32; break;
				default:
					show_debug_message("[CAudio] [FLAC] E: Reserved sample size code.");
					return(-1);
			};
			
			var headerCrcPosAbs = (_br.tell());
			if (_br.bitPos != 0) {
				show_debug_message("[CAudio] [FLAC] E: Frame header not byte aligned before CRC.");
				return(-1);
			};
			var headerCrc = (_br.readBits(8));
			if (_verifyCrc) {
				var calc = (_br.peekRangeCrc8(frameStartAbs, headerCrcPosAbs - frameStartAbs, self.calcCrc8));
				if (calc != headerCrc) {
					show_debug_message($"[CAudio] [FLAC] E: Frame header CRC mismatch { calc } != { headerCrc }.");
					return(-1);
				};
			};
			
			var channels = 0;
			var sideMode = 0; // 0=indep, 1=left-side, 2=right-side, 3=mid-side
			if (channelAssign < 8) {
				channels = (channelAssign + 1);
				sideMode = 0;
			} elif (channelAssign == 8) {
				channels = 2; sideMode = 1;
			} elif (channelAssign == 9) {
				channels = 2; sideMode = 2;
			} elif (channelAssign == 10) {
				channels = 2; sideMode = 3;
			} else {
				show_debug_message("[CAudio] [FLAC] E: Reserved channel assignment.");
				return(-1);
			};
			if (channels != (_streamInfo.channels)) {
				show_debug_message("[CAudio] [FLAC] W: Frame channel count differs from STREAMINFO.");
			};
			
			var ch = 0; while (ch < channels) {
				if (!is_array(_channelBufs[ch])) then _channelBufs[ch] = (array_create(blockSize));
				elif ((array_length(_channelBufs[ch])) < blockSize) then _channelBufs[ch] = (array_create(blockSize));
				var residual = undefined;
				if (is_array(_residualBufs)) {
					if (!is_array(_residualBufs[ch]) || (array_length(_residualBufs[ch]) < blockSize)) then _residualBufs[ch] = (array_create(blockSize));
					residual = (_residualBufs[ch]);
				};
				var bpsCh = bits;
				if ((sideMode == 1) && (ch == 1)) then bpsCh += 1;
				elif ((sideMode == 2) && (ch == 0)) then bpsCh += 1;
				elif ((sideMode == 3) && (ch == 1)) then bpsCh += 1;
				if (!(self.decodeSubframe(_br, bpsCh, blockSize, _channelBufs[ch], residual))) then return(-1);
				ch += 1;
			};
			
			_br.alignByte();
			var frameEndNoCrcAbs = (_br.tell());
			var frameCrc = (_br.readBits(16));
			if (_verifyCrc) {
				var calc16 = (_br.peekRangeCrc8(frameStartAbs, frameEndNoCrcAbs - frameStartAbs, self.calcCrc16));
				if (calc16 != frameCrc) {
					show_debug_message($"[CAudio] [FLAC] E: Frame CRC mismatch { calc16 } != { frameCrc }.");
					return(-1);
				};
			};
			
			// channel decorrelation
			if (sideMode == 1) {
				// left, side -> right = left - side
				var i = 0; while (i < blockSize) {
					var L = (_channelBufs[0][i]);
					var S = (_channelBufs[1][i]);
					_channelBufs[1][i] = (L - S);
					i += 1;
				};
			} elif (sideMode == 2) {
				// side, right -> left = right + side
				var i = 0; while (i < blockSize) {
					var S = (_channelBufs[0][i]);
					var R = (_channelBufs[1][i]);
					_channelBufs[0][i] = (R + S);
					i += 1;
				};
			} elif (sideMode == 3) {
				// mid, side
				var i = 0; while (i < blockSize) {
					var mid = (_channelBufs[0][i]);
					var side = (_channelBufs[1][i]);
					mid = ((mid << 1) | (side & 1));
					_channelBufs[0][i] = ((mid + side) >> 1);
					_channelBufs[1][i] = ((mid - side) >> 1);
					i += 1;
				};
			};
			
			return({
				blockSize: blockSize,
				channels: channels,
				sampleRate: sampleRate,
				bits: bits,
				sideMode: sideMode,
				codedNumber: codedNumber,
				blockingStrategy: blockingStrategy,
			});
		},
		
		writePcmInterleaved: function(_pcm, _writePos, _channelBufs, _channels, _blockSize, _srcBits, _dstIsU8, _srcOffset = 0) {
			var shiftDown = (max(0, _srcBits - 16));
			var i = _srcOffset;
			var sampleEnd = (_srcOffset + _blockSize);
			while (i < sampleEnd) {
				var ch = 0; while (ch < _channels) {
					var s = (_channelBufs[ch][i]);
					if (shiftDown > 0) then s = (s >> shiftDown);
					if (_dstIsU8) {
						// 8-bit FLAC is signed in stream; WAV PCM 8-bit is unsigned
						var u = (clamp(s + 128, 0, 255));
						buffer_poke(_pcm, _writePos, buffer_u8, u);
						_writePos += 1;
					} else {
						if (s > 32767) then s = 32767;
						elif (s < -32768) then s = -32768;
						buffer_poke(_pcm, _writePos, buffer_s16, s);
						_writePos += 2;
					};
					ch += 1;
				};
				i += 1;
			};
			return(_writePos);
		},
		
		decodeAll: function(_header) {
			var si = (_header.streamInfo);
			var br = (_header.bitReader);
			br.bytePos = (_header.firstFrameByte);
			br.bitPos = 0;
			
			var channels = (si.channels);
			var bits = (si.bits);
			var totalSamples = (si.totalSamples);
			var maxBlock = (max(si.maxBlock, 1));
			
			var outBits = ((bits <= 8) ? 8 : 16);
			var bytesPerSample = ((outBits == 8) ? 1 : 2);
			var estSamples = ((totalSamples > 0) ? totalSamples : 0);
			var pcmSize = 0;
			if (estSamples > 0) {
				pcmSize = (estSamples * channels * bytesPerSample);
			} else {
				// unknown total: grow later — start with 1s worth
				pcmSize = ((si.sampleRate) * channels * bytesPerSample);
			};
			if (pcmSize <= 0) then pcmSize = (maxBlock * channels * bytesPerSample);
			
			var pcm = (buffer_create(pcmSize, buffer_fixed, 1));
			var writePos = 0;
			var decodedSamples = 0;
			var channelBufs = (array_create(channels));
			var residualBufs = (array_create(channels));
			var ch = 0; while (ch < channels) {
				channelBufs[ch] = (array_create(maxBlock));
				residualBufs[ch] = (array_create(maxBlock));
				ch += 1;
			};
			
			var frames = 0;
			while (br.bytesLeft() >= 4) {
				var fr = (self.decodeFrame(br, si, channelBufs, true, residualBufs));
				if (fr == 0) then break;
				if (fr == -1) {
					buffer_delete(pcm);
					return(-1);
				};
				
				var need = (writePos + ((fr.blockSize) * channels * bytesPerSample));
				if (need > (buffer_get_size(pcm))) {
					var grownSize = (need + (si.sampleRate * channels * bytesPerSample));
					buffer_resize(pcm, grownSize);
				};
				writePos = (self.writePcmInterleaved(pcm, writePos, channelBufs, fr.channels, fr.blockSize, fr.bits, (outBits == 8)));
				decodedSamples += (fr.blockSize);
				frames += 1;
				if ((frames % 200) == 0) then show_debug_message($"[CAudio] [FLAC] decoding frames={ frames } samples={ decodedSamples }");
				if ((totalSamples > 0) && (decodedSamples >= totalSamples)) then break;
			};
			
			if ((decodedSamples <= 0) || ((totalSamples > 0) && (decodedSamples != totalSamples))) {
				show_debug_message($"[CAudio] [FLAC] E: Incomplete decode: { decodedSamples }/{ totalSamples } samples.");
				buffer_delete(pcm);
				return(-1);
			};
			
			// Trim spare capacity while preserving the audio-compatible fixed buffer type.
			if ((buffer_get_size(pcm)) != writePos) then buffer_resize(pcm, writePos);
			
			return({
				pcm: pcm,
				pcmSize: writePos,
				decodedSamples: decodedSamples,
				frames: frames,
				outBits: outBits,
			});
		},
	};
	return(helper);
};


function CAudioBitReader(_buffer, _path = undefined, _fileOrigin = 0, _fileSize = -1, _windowed = false) constructor {
	// absolute file coords: window covers [fileOrigin, fileOrigin+size)
	path = _path;
	fileOrigin = _fileOrigin;
	fileSize = ((_fileSize < 0) ? (buffer_get_size(_buffer)) : _fileSize);
	windowed = (bool(_windowed) && is_string(_path));
	windowSize = 262144; // 256KB sliding window
	crcBufferHits = 0;
	crcFileLoads = 0;
	buffer = _buffer;
	size = (buffer_get_size(_buffer));
	bytePos = 0; // relative to window start
	bitPos = 0;
	absPos = _fileOrigin; // absolute byte at window+bytePos when bitPos==0... maintained carefully
	
	static tell = function() {
		return(fileOrigin + bytePos);
	};
	
	static tellBits = function() {
		return(((fileOrigin + bytePos) * 8) + bitPos);
	};
	
	static bytesLeft = function() {
		return(max(0, fileSize - (fileOrigin + bytePos)));
	};
	
	static destroy = function() {
		if (buffer_exists(buffer)) then buffer_delete(buffer);
		buffer = -1;
		size = 0;
	};
	
	static ensure = function(_needBytes) {
		if (!windowed) then return(true);
		var absByte = (fileOrigin + bytePos);
		var remainInWindow = (size - bytePos);
		if ((_needBytes <= remainInWindow) && (absByte + _needBytes <= fileSize)) then return(true);
		// reload window starting at absByte (keep bitPos)
		var loadN = (min(windowSize, fileSize - absByte));
		if (loadN <= 0) then return(false);
		if (loadN < _needBytes) {
			// expand one-shot if a single read needs more than window
			loadN = (min(max(_needBytes, windowSize), fileSize - absByte));
		};
		if (buffer_exists(buffer)) then buffer_delete(buffer);
		buffer = (buffer_create(loadN, buffer_fixed, 1));
		buffer_load_partial(buffer, path, absByte, loadN, 0);
		fileOrigin = absByte;
		bytePos = 0;
		size = loadN;
		return(true);
	};
	
	static seek = function(_absByte) {
		if ((_absByte < 0) || (_absByte > fileSize)) then return(false);
		bitPos = 0;
		if (!windowed) {
			bytePos = _absByte;
			fileOrigin = 0;
			return(true);
		};
		if ((_absByte >= fileOrigin) && (_absByte < fileOrigin + size)) {
			bytePos = (_absByte - fileOrigin);
			return(true);
		};
		fileOrigin = _absByte;
		bytePos = 0;
		// force reload on next ensure
		if (buffer_exists(buffer)) then buffer_delete(buffer);
		buffer = (buffer_create(1, buffer_fixed, 1));
		size = 0;
		return(self.ensure(1));
	};
	
	static alignByte = function() {
		if (bitPos != 0) {
			bytePos += 1;
			bitPos = 0;
		};
	};
	
	static skipBits = function(_n) {
		if (_n <= 0) then return;
		var totalBits = (((fileOrigin + bytePos) * 8) + bitPos + _n);
		var absByte = (totalBits div 8);
		var targetBit = (totalBits mod 8);
		if (!windowed) {
			fileOrigin = 0;
			bytePos = absByte;
			bitPos = targetBit;
			return;
		};
		if ((absByte >= fileOrigin) && (absByte < fileOrigin + size)) {
			bytePos = (absByte - fileOrigin);
			bitPos = targetBit;
			return;
		};
		// reposition window
		fileOrigin = absByte;
		bytePos = 0;
		bitPos = targetBit;
		if (buffer_exists(buffer)) then buffer_delete(buffer);
		buffer = (buffer_create(1, buffer_fixed, 1));
		size = 0;
		if ((absByte < fileSize) || (bitPos == 0)) then self.ensure(1);
	};
	
	static readBits = function(_n) {
		if (_n <= 0) then return(0);
		var v = int64(0);
		var left = _n;
		while (left > 0) {
			if ((fileOrigin + bytePos) >= fileSize) {
				show_debug_message("[CAudio] [FLAC] E: BitReader underrun.");
				return(0);
			};
			if ((bytePos >= size) || (size == 0)) {
				if (!(self.ensure(max(16, left)))) {
					show_debug_message("[CAudio] [FLAC] E: BitReader window fill failed.");
					return(0);
				};
			};
			var cur = (buffer_peek(buffer, bytePos, buffer_u8));
			var avail = (8 - bitPos);
			var take = (min(left, avail));
			var shift = (avail - take);
			var mask = ((1 << take) - 1);
			v = ((v << take) | ((cur >> shift) & mask));
			bitPos += take;
			if (bitPos >= 8) {
				bitPos = 0;
				bytePos += 1;
			};
			left -= take;
		};
		return(real(v));
	};

	static readUnaryZeroes = function() {
		var count = 0;
		while (count <= 1000000) {
			if ((fileOrigin + bytePos) >= fileSize) {
				show_debug_message("[CAudio] [FLAC] E: Rice unary underrun.");
				return(undefined);
			};
			if ((bytePos >= size) || (size == 0)) {
				if (!(self.ensure(1))) {
					show_debug_message("[CAudio] [FLAC] E: Rice unary window fill failed.");
					return(undefined);
				};
			};
			var cur = (buffer_peek(buffer, bytePos, buffer_u8));
			if ((bitPos == 0) && (cur == 0)) {
				count += 8;
				bytePos += 1;
				continue;
			};
			while (bitPos < 8) {
				var bit = ((cur >> (7 - bitPos)) & 1);
				bitPos += 1;
				if (bit != 0) {
					if (bitPos == 8) {
						bitPos = 0;
						bytePos += 1;
					};
					return(count);
				};
				count += 1;
			};
			bitPos = 0;
			bytePos += 1;
		};
		show_debug_message("[CAudio] [FLAC] E: Rice unary overflow.");
		return(undefined);
	};
	
	static readSignedBits = function(_n) {
		if (_n <= 0) then return(0);
		var u = (self.readBits(_n));
		var signBit = (1 << (_n - 1));
		if ((u & signBit) != 0) then return(u - (1 << _n));
		return(u);
	};
	
	static peekRangeCrc8 = function(_absStart, _len, _crcFn) {
		if (!windowed) {
			return(_crcFn(buffer, _absStart, _len));
		};
		if ((_absStart >= fileOrigin) && (_absStart + _len <= fileOrigin + size)) {
			crcBufferHits += 1;
			return(_crcFn(buffer, _absStart - fileOrigin, _len));
		};
		crcFileLoads += 1;
		var tmp = (buffer_create(_len, buffer_fixed, 1));
		buffer_load_partial(tmp, path, _absStart, _len, 0);
		var r = (_crcFn(tmp, 0, _len));
		buffer_delete(tmp);
		return(r);
	};
};

function caudio_create_sound_flac(_path) {
	static helper = (caudio_flac());
	var header = (helper.parseHeader(_path, true));
	if (header == -1) then return(-1);
	
	show_debug_message($"[CAudio] [FLAC] STREAMINFO rate={ header.sampleRate } ch={ header.channels } bits={ header.bits } samples={ header.totalSamples } duration={ header.duration }");
	
	var decoded = (helper.decodeAll(header));
	if (is_struct(header.bitReader)) then header.bitReader.destroy();
	header.bitReader = undefined;
	
	if (decoded == -1) then return(-1);
	
	var _data_size = (decoded.pcmSize);
	var outBits = (decoded.outBits);
	var audioBuffer = decoded.pcm;
	decoded.pcm = -1;
	var btype = (helper.parseBufferDataType(outBits));
	var ctype = (helper.parseAudioChannelType(header.channels));
	
	var audioID = (audio_create_buffer_sound(audioBuffer, btype, (header.sampleRate), 0, _data_size, ctype));
	if (audioID == -1) {
		show_debug_message("[CAudio] [FLAC] E: audio_create_buffer_sound failed.");
		buffer_delete(audioBuffer);
		return(-1);
	};
	
	header.dataSize = _data_size;
	header.outBits = outBits;
	header.decodedSamples = (decoded.decodedSamples);
	header.frames = (decoded.frames);
	header.duration = ((header.sampleRate > 0) ? (((decoded.decodedSamples * 0.5) / header.sampleRate) * 2) : header.duration);
	
	show_debug_message($"[CAudio] [FLAC] OK frames={ decoded.frames } samples={ decoded.decodedSamples } pcmBytes={ _data_size }");
	return({ audioID, header, audioBuffer, path: _path, kind: "flac", mode: "buffer" });
};


function caudio_create_stream_flac(_path) {
	static helper = (caudio_flac());
	var header = (helper.parseHeader(_path, false));
	if (header == -1) then return(-1);
	
	var outBits = (((header.bits) <= 8) ? 8 : 16);
	var btype = (helper.parseBufferDataType(outBits));
	var ctype = (helper.parseAudioChannelType(header.channels));
	var audioQueue = (audio_create_play_queue(btype, (header.sampleRate), ctype));
	if (audioQueue < 0) {
		show_debug_message("[CAudio] [FLAC] E: audio_create_play_queue failed.");
		if (is_struct(header.bitReader)) then header.bitReader.destroy();
		return(-1);
	};
	
	var maxBlock = (max((header.maxBlock), 1));
	var framesPerFill = (max(1, ceil(((header.sampleRate) * 0.5) / maxBlock))); // ~0.5s PCM per queue buffer
	var channelBufs = (array_create(header.channels));
	var residualBufs = (array_create(header.channels));
	var ch = 0; while (ch < (header.channels)) {
		channelBufs[ch] = (array_create(maxBlock));
		residualBufs[ch] = (array_create(maxBlock));
		ch += 1;
	};
	
	var br = (header.bitReader);
	br.seek(header.firstFrameByte);
	
	show_debug_message($"[CAudio] [FLAC] stream ready (windowed) rate={ header.sampleRate } ch={ header.channels } bits={ header.bits } framesPerFill={ framesPerFill } duration={ header.duration }");
	
	return({
		audioQueue: audioQueue,
		header: header,
		path: _path,
		bitReader: br,
		channelBufs: channelBufs,
		residualBufs: residualBufs,
		outBits: outBits,
		framesPerFill: framesPerFill,
		maxBlock: maxBlock,
		decodedSamples: 0,
		totalSamples: (header.totalSamples),
		pendingFrame: undefined,
		pendingSkip: 0,
		done: false,
		failed: false,
		queued: 0,
		queueBuffers: [],
		queueStarts: [],
		queueSamples: [],
		queueGeneration: 0,
		retiredQueues: [],
		playBaseSeconds: 0,
		loop: false,
		kind: "flac",
		mode: "stream",
		playId: -1,
	});
};

function caudio_stream_fill_flac(_stream) {
	static helper = (caudio_flac());
	if (!is_struct(_stream)) then return(false);
	if (_stream.done) then return(false);
	
	var si = (_stream.header.streamInfo);
	var br = (_stream.bitReader);
	var channels = (_stream.header.channels);
	var bps = (((_stream.outBits) == 8) ? 1 : 2);
	var maxSamples = ((_stream.framesPerFill) * (_stream.maxBlock));
	var maxBytes = (maxSamples * channels * bps);
	if (maxBytes <= 0) then return(false);
	
	var pcm = (buffer_create(maxBytes, buffer_fixed, 1));
	var writePos = 0;
	var frames = 0;
	var rewoundWithoutFrame = false;
	var chunkStart = (_stream.decodedSamples);
	var chunkSamples = 0;
	
	while (frames < (_stream.framesPerFill)) {
		if (is_struct(_stream.pendingFrame)) {
			var pending = (_stream.pendingFrame);
			var pendingCount = ((pending.blockSize) - (_stream.pendingSkip));
			writePos = (helper.writePcmInterleaved(pcm, writePos, (_stream.channelBufs), (pending.channels), pendingCount, (pending.bits), ((_stream.outBits) == 8), (_stream.pendingSkip)));
			_stream.decodedSamples += pendingCount;
			chunkSamples += pendingCount;
			_stream.pendingFrame = undefined;
			_stream.pendingSkip = 0;
			frames += 1;
			rewoundWithoutFrame = false;
			continue;
		};
		if (((_stream.totalSamples) > 0) && ((_stream.decodedSamples) >= (_stream.totalSamples))) {
			if (_stream.loop) {
				if (rewoundWithoutFrame) {
					_stream.done = true;
					break;
				};
				rewoundWithoutFrame = true;
				_stream.decodedSamples = 0;
				br.seek(_stream.header.firstFrameByte);
				continue;
			};
			_stream.done = true;
			break;
		};
		if ((br.bytesLeft()) < 4) {
			if (((_stream.totalSamples) > 0) && ((_stream.decodedSamples) < (_stream.totalSamples))) {
				show_debug_message($"[CAudio] [FLAC] E: Truncated stream: { _stream.decodedSamples }/{ _stream.totalSamples } samples.");
				_stream.failed = true;
				_stream.done = true;
				break;
			};
			if (((_stream.totalSamples) == 0) && ((_stream.decodedSamples) > 0)) {
				_stream.totalSamples = _stream.decodedSamples;
				_stream.header.totalSamples = _stream.decodedSamples;
				_stream.header.duration = (_stream.decodedSamples / _stream.header.sampleRate);
			};
			if (_stream.loop) {
				if (rewoundWithoutFrame) {
					_stream.done = true;
					break;
				};
				rewoundWithoutFrame = true;
				_stream.decodedSamples = 0;
				br.seek(_stream.header.firstFrameByte);
				continue;
			};
			_stream.done = true;
			break;
		};
		
		var fr = (helper.decodeFrame(br, si, (_stream.channelBufs), true, (_stream.residualBufs)));
		if (fr == 0) {
			if (((_stream.totalSamples) > 0) && ((_stream.decodedSamples) < (_stream.totalSamples))) {
				show_debug_message($"[CAudio] [FLAC] E: Incomplete stream: { _stream.decodedSamples }/{ _stream.totalSamples } samples.");
				_stream.failed = true;
				_stream.done = true;
				break;
			};
			if (((_stream.totalSamples) == 0) && ((_stream.decodedSamples) > 0)) {
				_stream.totalSamples = _stream.decodedSamples;
				_stream.header.totalSamples = _stream.decodedSamples;
				_stream.header.duration = (_stream.decodedSamples / _stream.header.sampleRate);
			};
			if (_stream.loop) {
				if (rewoundWithoutFrame) {
					_stream.done = true;
					break;
				};
				rewoundWithoutFrame = true;
				_stream.decodedSamples = 0;
				br.seek(_stream.header.firstFrameByte);
				continue;
			};
			_stream.done = true;
			break;
		};
		if (fr == -1) {
			show_debug_message("[CAudio] [FLAC] E: stream frame decode failed.");
			buffer_delete(pcm);
			_stream.failed = true;
			_stream.done = true;
			return(false);
		};
		
		var need = (writePos + ((fr.blockSize) * channels * bps));
		if (need > maxBytes) {
			// rare: grow once
			var grown = (buffer_create(need, buffer_fixed, 1));
			if (writePos > 0) then buffer_copy(pcm, 0, writePos, grown, 0);
			buffer_delete(pcm);
			pcm = grown;
			maxBytes = need;
		};
		
		writePos = (helper.writePcmInterleaved(pcm, writePos, (_stream.channelBufs), (fr.channels), (fr.blockSize), (fr.bits), ((_stream.outBits) == 8)));
		_stream.decodedSamples += (fr.blockSize);
		chunkSamples += (fr.blockSize);
		frames += 1;
		rewoundWithoutFrame = false;
	};
	
	if (_stream.failed || (writePos <= 0)) {
		buffer_delete(pcm);
		return(false);
	};
	
	audio_queue_sound((_stream.audioQueue), pcm, 0, writePos);
	array_push(_stream.queueBuffers, pcm);
	array_push(_stream.queueStarts, chunkStart);
	array_push(_stream.queueSamples, chunkSamples);
	_stream.queued = (array_length(_stream.queueBuffers));
	return(true);
};

function caudio_stream_prime_flac(_stream, _min_queued = 3) {
	if (!is_struct(_stream)) then return(0);
	var _n = 0;
	while (((_stream.queued) < _min_queued) && (caudio_stream_fill_flac(_stream))) {
		_n += 1;
	};
	return(_n);
};

function caudio_stream_on_async_flac(_stream, _async_map, _min_queued = 3) {
	if (!is_struct(_stream)) then return;
	var _bid = (_async_map[? "buffer_id"]);
	var _qid = (_async_map[? "queue_id"]);
	var _index = (array_get_index(_stream.queueBuffers, _bid));
	if ((_qid == (_stream.audioQueue)) && (_index >= 0)) {
		var _completed_sample = (_stream.queueStarts[_index] + _stream.queueSamples[_index]);
		if (buffer_exists(_bid)) then buffer_delete(_bid);
		array_delete(_stream.queueBuffers, _index, 1);
		array_delete(_stream.queueStarts, _index, 1);
		array_delete(_stream.queueSamples, _index, 1);
		_stream.queued = (array_length(_stream.queueBuffers));
		var _base_sample = ((_stream.queued > 0) ? _stream.queueStarts[0] : _completed_sample);
		_stream.playBaseSeconds = (((_base_sample * 0.5) / _stream.header.sampleRate) * 2);
		if ((_stream.queued) < _min_queued) then caudio_stream_fill_flac(_stream);
		return;
	};
	var _queue_index = 0;
	while (_queue_index < array_length(_stream.retiredQueues)) {
		var _retired_queue = _stream.retiredQueues[_queue_index];
		if ((_retired_queue.queueId) == _qid) {
			var _retired_buffer = (array_get_index(_retired_queue.buffers, _bid));
			if (_retired_buffer >= 0) {
				if ((_index < 0) && buffer_exists(_bid)) then buffer_delete(_bid);
				array_delete(_retired_queue.buffers, _retired_buffer, 1);
				if (array_length(_retired_queue.buffers) == 0) then array_delete(_stream.retiredQueues, _queue_index, 1);
				return;
			};
		};
		_queue_index += 1;
	};
};

function caudio_stream_free_flac(_stream) {
	if (!is_struct(_stream)) then return;
	if (audio_exists(_stream.playId)) then audio_stop_sound(_stream.playId);
	_stream.playId = -1;
	var _retired_index = 0;
	while (_retired_index < array_length(_stream.retiredQueues)) {
		var _retired = _stream.retiredQueues[_retired_index];
		caudio_retired_queue_register(_retired.queueId, _retired.buffers);
		_retired_index += 1;
	};
	_stream.retiredQueues = [];
	if (variable_struct_exists(_stream, "audioQueue") && ((_stream.audioQueue) >= 0)) {
		caudio_retired_queue_register(_stream.audioQueue, _stream.queueBuffers);
		audio_free_play_queue(_stream.audioQueue);
		_stream.audioQueue = -1;
	};
	if (variable_struct_exists(_stream, "bitReader") && is_struct(_stream.bitReader)) {
		_stream.bitReader.destroy();
		_stream.bitReader = undefined;
	};
	_stream.done = true;
	_stream.queued = 0;
	_stream.queueBuffers = [];
	_stream.queueStarts = [];
	_stream.queueSamples = [];
};


function caudio_free_sound_flac(_sound) {
	if (!is_struct(_sound)) then return;
	if (variable_struct_exists(_sound, "audioID") && audio_exists(_sound.audioID)) {
		audio_stop_sound(_sound.audioID);
		audio_free_buffer_sound(_sound.audioID);
		_sound.audioID = -1;
	};
	if (variable_struct_exists(_sound, "audioBuffer") && buffer_exists(_sound.audioBuffer)) {
		buffer_delete(_sound.audioBuffer);
		_sound.audioBuffer = -1;
	};
};


function caudio_stream_set_loop_flac(_stream, _loop) {
	if (!is_struct(_stream)) then return(false);
	_stream.loop = (bool(_loop));
	if (_stream.loop && _stream.done && !(_stream.failed)) then _stream.done = false;
	return(true);
};

function caudio_stream_seek_flac(_stream, _seconds) {
	static helper = (caudio_flac());
	if (!is_struct(_stream)) then return(-1);
	if ((_stream.mode) != "stream") then return(-1);
	
	var rate = (_stream.header.sampleRate);
	if (rate <= 0) then return(-1);
	var target = (max(0, floor(_seconds * rate)));
	if (((_stream.totalSamples) > 0) && (target >= (_stream.totalSamples))) {
		if (_stream.loop) then target = 0;
		else target = (max(0, (_stream.totalSamples) - 1));
	};
	
	// pick best seektable point <= target
	var pts = (variable_struct_exists(_stream.header, "seekPoints") ? _stream.header.seekPoints : []);
	var bestSample = 0;
	var bestOffset = 0;
	var i = 0; while (i < (array_length(pts))) {
		var p = (pts[i]);
		if ((p.sample) <= target) {
			bestSample = (p.sample);
			bestOffset = (p.offset);
		} else break;
		i += 1;
	};
	
	var absByte = ((_stream.header.firstFrameByte) + bestOffset);
	var br = (_stream.bitReader);
	var oldByte = br.tell();
	var oldBit = br.bitPos;
	br.seek(absByte);
	
	// Decode to the frame containing target, then retain its unwritten suffix.
	var si = (_stream.header.streamInfo);
	var seekChannels = (array_create(_stream.header.channels));
	var seekResiduals = (array_create(_stream.header.channels));
	var seekChannel = 0;
	while (seekChannel < _stream.header.channels) {
		seekChannels[seekChannel] = (array_create(_stream.maxBlock));
		seekResiduals[seekChannel] = (array_create(_stream.maxBlock));
		seekChannel += 1;
	};
	var decoded = bestSample;
	var guard = 0;
	var pendingFrame = undefined;
	var pendingSkip = 0;
	while ((decoded < target) && (br.bytesLeft() >= 4) && (guard < 100000)) {
		var fr = (helper.decodeFrame(br, si, seekChannels, true, seekResiduals));
		if ((fr == 0) || (fr == -1)) then break;
		var frameEnd = (decoded + (fr.blockSize));
		if (target < frameEnd) {
			pendingFrame = fr;
			pendingSkip = (target - decoded);
			decoded = target;
			break;
		};
		decoded = frameEnd;
		guard += 1;
	};
	if (decoded != target) {
		br.seek(oldByte);
		br.bitPos = oldBit;
		show_debug_message($"[CAudio] [FLAC] E: Could not seek to sample { target }.");
		return(-1);
	};
	
	// recreate play queue so old PCM is discarded
	var btype = (helper.parseBufferDataType(_stream.outBits));
	var ctype = (helper.parseAudioChannelType(_stream.header.channels));
	var replacementQueue = (audio_create_play_queue(btype, rate, ctype));
	if (replacementQueue < 0) {
		br.seek(oldByte);
		br.bitPos = oldBit;
		return(-1);
	};

	_stream.channelBufs = seekChannels;
	_stream.residualBufs = seekResiduals;
	_stream.decodedSamples = decoded;
	_stream.pendingFrame = pendingFrame;
	_stream.pendingSkip = pendingSkip;
	_stream.done = false;

	if ((_stream.audioQueue) >= 0) {
		if (audio_exists(_stream.playId)) then audio_stop_sound(_stream.playId);
		if (array_length(_stream.queueBuffers) > 0) then array_push(_stream.retiredQueues, { queueId: _stream.audioQueue, generation: _stream.queueGeneration, buffers: _stream.queueBuffers });
		audio_free_play_queue(_stream.audioQueue);
	};
	_stream.audioQueue = replacementQueue;
	_stream.queueGeneration += 1;
	_stream.queued = 0;
	_stream.queueBuffers = [];
	_stream.queueStarts = [];
	_stream.queueSamples = [];
	_stream.playBaseSeconds = (((target * 0.5) / rate) * 2);
	_stream.playId = -1;
	
	var primed = (caudio_stream_prime_flac(_stream, 5));
	show_debug_message($"[CAudio] [FLAC] seek t={ _seconds }s sample={ target } pts={ array_length(pts) } primed={ primed }");
	return(((target * 0.5) / rate) * 2);
};

function caudio_stream_get_position_flac(_stream) {
	if (!is_struct(_stream)) then return(0);
	var rate = (_stream.header.sampleRate);
	if (rate <= 0) then return(0);
	var pos = (((_stream.decodedSamples * 0.5) / rate) * 2);
	if (audio_exists(_stream.playId)) {
		pos = ((_stream.playBaseSeconds) + audio_sound_get_track_position(_stream.playId));
	} elif ((array_length(_stream.queueStarts)) > 0) {
		pos = (((_stream.queueStarts[0] * 0.5) / rate) * 2);
	};
	var duration = (_stream.header.duration);
	if (_stream.loop && (duration > 0)) {
		var _total_samples = max(1, _stream.totalSamples);
		var _position_sample = floor(pos * rate);
		_position_sample -= (floor(_position_sample / _total_samples) * _total_samples);
		pos = (_position_sample / rate);
		pos = min(pos, max(0, duration - (1.0 / rate)));
	}
	elif (duration > 0) then pos = (min(pos, duration));
	return(pos);
};

/* ended */
