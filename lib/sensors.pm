#!/usr/bin/perl

use strict;
use warnings;
use List::Util qw(sum);
use Device::USB::PCSensor::HidTEMPer;

#** @var $fh default fileHandler
my $fh;
#** @var @temperature stores multible temperatures
my @temperature;
#** @var @temp temporary storage
my @temp;
#** @var $debug debug flag, 3 print return values, 4 print temperatures, 5 print function references
my $debug=0;
#** @var $temper stores HidTEMPer object
my $temper;


#** @function public  getHidTEMPer()
# @brief get HidTEMPer temperature 
# @todo add UniqID if possible need another sensor!
# @retval 'float NUM' if no error
# @retval 'char U' if error
#* 
sub getHidTEMPer{
	my $temper = Device::USB::PCSensor::HidTEMPer->new();
	#** @var $sensorID XXX
	my $sensorID = $temper->device();

	#** temporary workaroud
	sleep(1);
	return $sensorID->internal()->celsius();
}

#** @function public bcm2708Temp ()
# @brief get bcm2708 temperature 
# @retval 'float NUM' if no error
# @retval 'char U' if error
#* 
sub getBCM2708{
        if( !(-r '/opt/vc/bin/vcgencmd') ){
                return "U";
        }

        @temp = `/opt/vc/bin/vcgencmd measure_temp`;
        if( !($temp[0] =~ m/^temp=(.*)'C$/) ){
                return "U";
        }
        else{
                $temp[0] = $1;
        }

        return $temp[0];
}


#** @function public getTempDS1820 ($ID)
# @brief get DS1820 temperature 
# @param requiered $ID ID of Sensor
# @retval 'float NUM' temperature if no error
# @retval 'char U' if error
#* 
sub getTempDS1820{
	if($debug > 3){
		print "\tgetTempDS1820 -> $_[0]\n";
	}

	open($fh, "<", "/sys/bus/w1/devices/$_[0]/w1_slave") or return "U";
	#** @var @temp stores recived string
	@temp = <$fh>;
	close($fh);

	if( !($temp[1]=~ m\t=(.*)\) ){
		return "U";
	}
		if($1 < -55000 || $1 > 125000){
		return "U";
	}
	else{
		return $1/1000;
	}
}

#** @function public fillArray ($function, $count, $SensorID)
# @brief fill @array $count times with $funtion
# @param required $function function to call
# @param required $count XXX
# @param optional $sensorID XXX
# @retval 'array ' XXX
#* 
sub fillArray{
	for(my $i=0; $i<$_[1]; $i++){
		$temperature[$i] = $_[0]($_[2]);
		if($debug>=3){
			print "\tfillArray -> $temperature[$i]\n";
		}
		sleep(1);
	}
	return @temperature;
}

#** @function public avgTemp ($func, $count, $tolerance, $sensorID])
# @brief get DS1820 temperature 
# @param required $func XXX
# @param required $count XXX
# @param required $tolerance XXX
# @param optional $sensorID XXX
# @todo if array value 'U' delete item
# @retval 'float NUM' temperature if no error
# @retval 'char U' if error
#* 
sub avgTemp{
	fillArray($_[0], "3", $_[3]);
	return (sum(@temperature)/@temperature);
}

1;
