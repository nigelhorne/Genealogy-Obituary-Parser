# Generated from Makefile.PL using makefilepl2cpanfile

requires 'perl', '5.008';

requires 'Carp';
requires 'DateTime::Format::Text';
requires 'JSON::MaybeXS';
requires 'Params::Get', '0.13';
requires 'Params::Validate::Strict', '0.10';
requires 'Return::Set', '0.03';

on 'test' => sub {
	requires 'Data::Random';
	requires 'File::Glob';
	requires 'File::Slurp';
	requires 'File::stat';
	requires 'IPC::System::Simple';
	requires 'POSIX';
	requires 'Readonly';
	requires 'Test::DescribeMe';
	requires 'Test::Most';
	requires 'Test::Needs';
	requires 'Test::Returns';
};
on 'develop' => sub {
	requires 'Devel::Cover';
	requires 'Perl::Critic';
	requires 'Test::Pod';
	requires 'Test::Pod::Coverage';
};
